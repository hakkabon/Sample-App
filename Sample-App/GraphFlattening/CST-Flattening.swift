//
//  CST-Flattening.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation
import SwiftLayout

final class SyntaxTreeNode {
    let label: String
    let children: [SyntaxTreeNode]
    init(label: String, children: [SyntaxTreeNode] = []) {
        self.label = label
        self.children = children
    }
}

struct SyntaxTreeFlattener: GraphFlattening {
    let root: SyntaxTreeNode
    let measure: (String) -> CGSize

    func flatten() -> (nodes: [FfiNode], edges: [FfiEdge], lookup: [UInt64: SyntaxTreeNode]) {
        let ids = NodeIDAllocator()
        var ffiNodes: [FfiNode] = []
        var ffiEdges: [FfiEdge] = []
        var lookup: [UInt64: SyntaxTreeNode] = [:]
        var visited = Set<ObjectIdentifier>()

        func visit(_ node: SyntaxTreeNode) {
            let id = ids.id(for: node)
            let key = ObjectIdentifier(node)

            if !visited.contains(key) {
                visited.insert(key)
                let size = measure(node.label)
                ffiNodes.append(FfiNode(id: id, width: Float(size.width), height: Float(size.height)))
                lookup[id] = node
            }

            for child in node.children {
                let childID = ids.id(for: child)
                ffiEdges.append(FfiEdge(from: id, to: childID, labelWidth: 30, labelHeight: 20))
                visit(child)
            }
        }

        visit(root)
        return (ffiNodes, ffiEdges, lookup)
    }
}
