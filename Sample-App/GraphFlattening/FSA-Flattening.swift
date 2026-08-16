//
//  FSA-Flattening.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation
import SwiftLayout

final class FSAState {
    let name: String
    let isAccepting: Bool
    var transitions: [(symbol: String, target: FSAState)] = []
    init(name: String, isAccepting: Bool = false) {
        self.name = name
        self.isAccepting = isAccepting
    }
}

struct FSAFlattener: GraphFlattening {
    let states: [FSAState]
    let measure: (String) -> CGSize

    func flatten() -> (nodes: [FfiNode], edges: [FfiEdge], lookup: [UInt64: FSAState]) {
        let ids = NodeIDAllocator()
        var ffiNodes: [FfiNode] = []
        var ffiEdges: [FfiEdge] = []
        var lookup: [UInt64: FSAState] = [:]
        var visited = Set<ObjectIdentifier>()
        var allStates: [FSAState] = []

        func discover(_ state: FSAState) {
            let key = ObjectIdentifier(state)
            guard !visited.contains(key) else { return }
            visited.insert(key)
            allStates.append(state)

            let id = ids.id(for: state)
            let size = measure(state.name)
            ffiNodes.append(FfiNode(id: id, width: Float(max(size.width, 40)), height: Float(max(size.height, 40))))
            lookup[id] = state

            for transition in state.transitions {
                discover(transition.target)
            }
        }

        for state in states {
            discover(state)
        }

        for state in allStates {
            let from = ids.id(for: state)
            for transition in state.transitions {
                let to = ids.id(for: transition.target)
                ffiEdges.append(FfiEdge(from: from, to: to))
            }
        }

        return (ffiNodes, ffiEdges, lookup)
    }
}
