//
//  main.swift
//
//
//  Created by Tongjie Wang on 8/17/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxParser

struct EnumInformation {
    let enumDecl: EnumDeclSyntax
    var cases: [EnumCaseElementSyntax] = []
}

final class MyVisitor: SyntaxVisitor {
    private var _result: [String: EnumInformation] = [:]
    private var _danglingCases: [EnumCaseElementSyntax] = []

    override func visit(_ node: EnumCaseElementSyntax) -> SyntaxVisitorContinueKind {
        if let parentEnum = _getParentEnum(ofCaseElement: node) {
            _result[parentEnum.identifier.text]?.cases.append(node)
        } else {
            _danglingCases.append(node)
        }
        return .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        _result[node.identifier.text] = EnumInformation(enumDecl: node)
        return .visitChildren
    }

    var result: [String: EnumInformation] {
        return _result
    }

    var danglingCases: [EnumCaseElementSyntax] {
        return _danglingCases
    }

    private func _getParentEnum(ofCaseElement node: EnumCaseElementSyntax) -> EnumDeclSyntax? {
        var parent = node.parent

        while let safeParent = parent {
            if let enumDecl = EnumDeclSyntax(safeParent) {
                return enumDecl
            }
            parent = safeParent.parent
        }

        return nil
    }
}

func checkSingleRepo(dirPath: String) {
    let dirEnumerator = FileManager.default.enumerator(atPath: dirPath)
    while var file = dirEnumerator?.nextObject() as? String {
        if !file.hasSuffix(".swift") {
            continue
        }
        file = "\(dirPath)/\(file)"
        var isDir = ObjCBool(false)
        if !FileManager.default.fileExists(atPath: file, isDirectory: &isDir) || isDir.boolValue {
            continue
        }
        guard let source = try? String(contentsOfFile: file) else {
            print("Failed to read file \(file)")
            continue
        }
        let visitor = MyVisitor()
        guard let sourceNode = try? SyntaxParser.parse(source: source) else {
            print("Failed to parse file \(file)")
            continue
        }
        visitor.walk(sourceNode)
        if !visitor.danglingCases.isEmpty {
            print("File \(file) has dangling cases!")
        }
        for (enumName, enumInfo) in visitor.result {
            if !Dictionary(grouping: enumInfo.cases, by: \.identifier.text).filter({
                $1.count > 1
            }).isEmpty {
                print(
                    "Found multiple cases with identical name in enum \(enumName) from file \(file)"
                )
            }
        }
    }
}

struct ProjectInfo: Decodable {
    let repository: String
    let url: URL
    let path: String
}

public func cloneGitRepo(url: URL, localPath: String) {
    do {
        let process = try Process.run(URL(fileURLWithPath: "/usr/bin/git"), arguments: ["clone", "--quiet", "--depth=1", url.absoluteString, localPath])
        process.waitUntilExit()
    } catch {
        print("Failed to clone \(url) because of error: \(error)")
    }
}

func main() {
    guard let projectInfoJSONData = try? String(contentsOfFile: "<#Path to source compatibility test project list JSON file#>").data(using: .utf8) else {
        print("Failed to open project list")
        return
    }
    guard let projects = try? JSONDecoder().decode([ProjectInfo].self, from: projectInfoJSONData) else {
        print("Failed to parse project list")
        return
    }
    let reposDir = "<#Path to directory containing all projects#>"
    for (progress, projectInfo) in projects.enumerated() {
        print("Progress: \(progress + 1) out of \(projects.count) repos")
        if projectInfo.repository != "Git" {
            continue
        }
        let repoDir = "\(reposDir)/\(projectInfo.path)"
        if !FileManager.default.fileExists(atPath: repoDir) {
            print("Cloning repo \(projectInfo.url)...")
            cloneGitRepo(url: projectInfo.url, localPath: repoDir)
        }
        print("Checking repo \(projectInfo.path)...")
        checkSingleRepo(dirPath: repoDir)
    }
}

main()

