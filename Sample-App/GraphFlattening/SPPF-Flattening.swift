//
//  SPPF-Flattening.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation
import SwiftLayout

/// A minimal SPPF node. Real SPPF nodes (Scott & Johnstone-style) come in
/// two flavors:
///   - symbol nodes, labeled by a grammar symbol (and span), which have
///     MULTIPLE packed-node children exactly when the input is ambiguous
///     (each packed child is one possible derivation);
///   - packed nodes, labeled by the grammar rule/production applied, which
///     hold the actual symbol children for that one derivation.
/// This stand-in captures just enough of that shape to demonstrate layout
/// with real ambiguity: shared subtrees plus alternative derivations.
final class SPPFNode {
    enum Kind {
        case symbol(String)   // e.g. "E"
        case packed(String)   // e.g. "E → E + E"
    }
    let kind: Kind
    var children: [SPPFNode] = []

    init(kind: Kind, children: [SPPFNode] = []) {
        self.kind = kind
        self.children = children
    }

    var isPacked: Bool {
        if case .packed = kind { return true }
        return false
    }

    var label: String {
        switch kind {
        case .symbol(let s), .packed(let s): return s
        }
    }
}

//  SPPF (Shared Packed Parse Forest) and GSS (Graph-Structured Stack)
//  domain models and flatteners. Both graph kinds are DAGs, not trees —
//  SPPF nodes get *shared* across derivations, and GSS nodes get *merged*
//  when two stack paths converge — which is exactly what `LayoutGraph`
//  supports beyond a plain tree (cycle breaking only matters if your
//  domain graph can be genuinely cyclic; these two are acyclic DAGs, so
//  `break_cycles` is a no-op for them, but the multi-parent fan-in still
//  needs the crossing-reduction/coordinate phases to look right).

struct SPPFFlattener: GraphFlattening {
    /// SPPF nodes are heavily shared (that's the point — it's a *shared*
    /// packed forest), so flattening tracks already-visited nodes by
    /// identity and only ever emits each one once, while every incoming
    /// edge to it still gets recorded.
    let roots: [SPPFNode]
    let measure: (String) -> CGSize

    func flatten() -> (nodes: [FfiNode], edges: [FfiEdge], lookup: [UInt64: SPPFNode]) {
        let ids = NodeIDAllocator()
        var ffiNodes: [FfiNode] = []
        var ffiEdges: [FfiEdge] = []
        var lookup: [UInt64: SPPFNode] = [:]
        var emitted = Set<ObjectIdentifier>()

        func visit(_ node: SPPFNode) {
            let id = ids.id(for: node)
            let key = ObjectIdentifier(node)
            if emitted.contains(key) {
                return // subtree already emitted via an earlier parent
            }
            emitted.insert(key)

            let size = measure(node.label)
            ffiNodes.append(FfiNode(id: id, width: Float(size.width), height: Float(size.height)))
            lookup[id] = node

            for child in node.children {
                let childID = ids.id(for: child)
                // Recorded unconditionally, even if `child` was already
                // visited elsewhere — that's what makes the sharing show
                // up as fan-in in the rendered graph.
                ffiEdges.append(FfiEdge(from: id, to: childID, labelWidth: 30, labelHeight: 20))
                visit(child)
            }
        }

        for root in roots {
            visit(root)
        }
        return (ffiNodes, ffiEdges, lookup)
    }
}
