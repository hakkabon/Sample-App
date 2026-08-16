//
//  GSS-Flattening.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation
import SwiftLayout

final class GSSNode {
    let label: String
    var predecessors: [GSSNode] = []
    init(label: String) { self.label = label }
}

struct GSSFlattener: GraphFlattening {
    let nodes: [GSSNode]
    let measure: (String) -> CGSize

    func flatten() -> (nodes: [FfiNode], edges: [FfiEdge], lookup: [UInt64: GSSNode]) {
        let ids = NodeIDAllocator()
        var ffiNodes: [FfiNode] = []
        var ffiEdges: [FfiEdge] = []
        var lookup: [UInt64: GSSNode] = [:]
        var visited = Set<ObjectIdentifier>()
        var allNodes: [GSSNode] = []

        func discover(_ node: GSSNode) {
            let key = ObjectIdentifier(node)
            guard !visited.contains(key) else { return }
            visited.insert(key)
            allNodes.append(node)

            let id = ids.id(for: node)
            let size = measure(node.label)
            ffiNodes.append(FfiNode(id: id, width: Float(max(size.width, 44)), height: Float(max(size.height, 36))))
            lookup[id] = node

            for predecessor in node.predecessors {
                discover(predecessor)
            }
        }

        for node in nodes {
            discover(node)
        }

        for node in allNodes {
            let from = ids.id(for: node)
            for predecessor in node.predecessors {
                let to = ids.id(for: predecessor)
                // Lay out top-to-bottom in push order (predecessor -> node)
                ffiEdges.append(FfiEdge(from: to, to: from))
            }
        }
        return (ffiNodes, ffiEdges, lookup)
    }
}
