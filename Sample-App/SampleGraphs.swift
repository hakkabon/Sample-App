//
//  SampleGraphs.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

//  Concrete example graphs for the gallery. Each one is small enough to
//  read at a glance but exercises something specific:
//    - Syntax Tree: operator precedence (`*` binds tighter than `+`)
//    - FSA/DFA: an accept state plus self-loop transitions — self-loops
//      specifically exercise `LayoutGraph::extract_self_loops` on the
//      Rust side (see FfiLayoutResult.selfLoops)
//    - SPPF: genuine ambiguity — two derivations of "a+a+a" sharing
//      subtrees, not just a tree with duplicate labels
//    - GSS: a merge, where two stack paths converge on one node —
//      exactly the multi-parent shape a plain tree can't represent

enum SampleGraphs {

    // MARK: Syntax Tree: "a + b * c"

    static func syntaxTree() -> SyntaxTreeNode {
        let a = SyntaxTreeNode(label: "a")
        let star = SyntaxTreeNode(label: "*")
        let b = SyntaxTreeNode(label: "b")
        let c = SyntaxTreeNode(label: "c")
        let bTimesC = SyntaxTreeNode(label: "Expr", children: [b, star, c])
        let plus = SyntaxTreeNode(label: "+")
        let root = SyntaxTreeNode(label: "Expr", children: [a, plus, bTimesC])
        return root
    }

    // MARK: FSA/DFA: strings over {a,b} containing "ab" as a substring

    static func fsa() -> [FSAState] {
        let q0 = FSAState(name: "q0")
        let q1 = FSAState(name: "q1")
        let q2 = FSAState(name: "q2", isAccepting: true)

        q0.transitions = [("a", q1), ("b", q0)]
        q1.transitions = [("a", q1), ("b", q2)]
        q2.transitions = [("a", q2), ("b", q2)]   // both self-loops once accepted

        return [q0, q1, q2]
    }

    // MARK: SPPF: two derivations of "a+a+a" for `E ::= E "+" E | "a"`

    static func sppf() -> [SPPFNode] {
        let a1 = SPPFNode(kind: .symbol("a"))
        let plus1 = SPPFNode(kind: .symbol("+"))
        let a2 = SPPFNode(kind: .symbol("a"))
        let plus2 = SPPFNode(kind: .symbol("+"))
        let a3 = SPPFNode(kind: .symbol("a"))

        func leaf(_ terminal: SPPFNode) -> SPPFNode {
            SPPFNode(kind: .symbol("E"), children: [SPPFNode(kind: .packed("E → a"), children: [terminal])])
        }
        let eA1 = leaf(a1)
        let eA2 = leaf(a2)
        let eA3 = leaf(a3)

        // E[0,2) = a1 + a2, and E[2,5) = a2 + a3 — both reuse eA2 and the
        // shared '+' terminals, not copies of them.
        let e12 = SPPFNode(kind: .symbol("E"), children: [
            SPPFNode(kind: .packed("E → E + E"), children: [eA1, plus1, eA2])
        ])
        let e23 = SPPFNode(kind: .symbol("E"), children: [
            SPPFNode(kind: .packed("E → E + E"), children: [eA2, plus2, eA3])
        ])

        // The top E node is where the ambiguity actually lives: two
        // packed children, i.e. two different ways to parenthesize
        // "a+a+a" — right-associative (a+(a+a)) vs left ((a+a)+a) — both
        // reusing eA1/eA2/eA3 rather than duplicating them.
        let rightAssoc = SPPFNode(kind: .packed("E → E + E  (a+(a+a))"), children: [eA1, plus1, e23])
        let leftAssoc = SPPFNode(kind: .packed("E → E + E  ((a+a)+a)"), children: [e12, plus2, eA3])
        let top = SPPFNode(kind: .symbol("E  [ambiguous]"), children: [rightAssoc, leftAssoc])

        return [top]
    }

    // MARK: GSS: a merge at v3, converging from two alternate paths through v1/v2

    static func gss() -> [GSSNode] {
        let v0 = GSSNode(label: "v0\n(q0, 0)")

        let v1 = GSSNode(label: "v1\n(q1, 1)")
        v1.predecessors = [v0]

        let v2 = GSSNode(label: "v2\n(q2, 1)")
        v2.predecessors = [v0]

        let v3 = GSSNode(label: "v3\n(q3, 2)")
        v3.predecessors = [v1, v2]   // the merge

        return [v0, v1, v2, v3]
    }
}
