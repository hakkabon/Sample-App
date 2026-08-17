//
//  GraphGallery.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import SwiftUI
import SwiftLayout

//  A picker over the four example graphs, each rendered through the same
//  GraphVisualizationView / GraphLayoutCoordinator pipeline used by
//  SyntaxTreeContainerView — only the flattener and node styling differ
//  per graph kind.

// MARK: - Gallery switcher

enum GraphKind: String, CaseIterable, Identifiable {
    case syntaxTree = "Syntax Tree"
    case fsa = "FSA / DFA"
    case sppf = "SPPF"
    case gss = "GSS"

    var id: String { rawValue }
}

struct GraphGalleryView: View {
    @State private var selection: GraphKind = .syntaxTree

    var body: some View {
        VStack(spacing: 0) {
            Picker("Graph", selection: $selection) {
                ForEach(GraphKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selection {
                case .syntaxTree:
                    SyntaxTreeContainerView(root: SampleGraphs.syntaxTree())
                case .fsa:
                    FSAContainerView(states: SampleGraphs.fsa())
                case .sppf:
                    SPPFContainerView(roots: SampleGraphs.sppf())
                case .gss:
                    GSSContainerView(nodes: SampleGraphs.gss())
                }
            }
            // Force a fresh container (and thus a fresh coordinator) per
            // graph kind, rather than reusing state across switches.
            .id(selection)
        }
    }
}

// MARK: - Shared node styling helpers

private func measureLabel(_ text: String) -> CGSize {
    // Stand-in text measurement. Swap in your real measurement helper
    // (e.g. via NSAttributedString.size(), matching whatever font each
    // node content view actually renders with) if label sizes need to be
    // pixel-accurate rather than "close enough for a demo".
    let lines = text.components(separatedBy: "\n")
    let widest = lines.map { CGFloat($0.count) }.max() ?? 0
    let width = widest * 8 + 20
    let height = CGFloat(lines.count) * 18 + 16
    return CGSize(width: max(width, 32), height: max(height, 32))
}

// MARK: - Syntax Tree

struct SyntaxTreeContainerView: View {
    let root: SyntaxTreeNode
    @StateObject private var coordinator = GraphLayoutCoordinator<SyntaxTreeNode>()
    @State private var algorithm: FfiAlgorithm = .brandesKopf
    @State private var anchor: GraphAnchor = .center

    var body: some View {
        VStack {
            Picker("Algorithm", selection: $algorithm) {
                Text("Median Relax").tag(FfiAlgorithm.medianRelax)
                Text("Brandes-Köpf").tag(FfiAlgorithm.brandesKopf)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            AnchorPicker(anchor: $anchor)

            AnchoredGraphView(coordinator: coordinator, anchor: anchor) { node in
                AnyView(
                    Text(node.label)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.primary))
                )
            }
        }
        // Re-layout when the tree identity or the chosen algorithm
        // changes — NOT on every view update. Pan/zoom should be a plain
        // SwiftUI transform on `coordinator.nodes`/`routes`, not a new
        // `relayout` call; see the earlier performance notes on caching
        // positions across pan/zoom.
        .task(id: ObjectIdentifier(root)) {
            await runLayout()
        }
        .onChange(of: algorithm) { _, _ in
            Task { await runLayout() }
        }
    }

    private func runLayout() async {
        let flattener = SyntaxTreeFlattener(root: root) { label in
            // Replace with your real text-measurement helper.
            CGSize(width: CGFloat(label.count) * 8 + 16, height: 28)
        }
        let config = FfiConfig(
                        hGap: 24,
                        vGap: 48,
                        relaxPasses: 4,
                        sweeps: 4,
                        algorithm: algorithm,
                        routing: .bezier,
                        direction: .topToBottom
                    )
        await coordinator.relayout(flattener, config: config)
    }
}


// MARK: - FSA / DFA

struct FSANodeView: View {
    let state: FSAState
    var body: some View {
        ZStack {
            Circle().fill(.background)
            Circle().stroke(.primary, lineWidth: 1.5)
            if state.isAccepting {
                Circle().stroke(.primary, lineWidth: 1.5).padding(4)
            }
            Text(state.name).font(.callout.monospaced())
        }
        .frame(width: 48, height: 48)
    }
}

struct FSAContainerView: View {
    let states: [FSAState]
    @StateObject private var coordinator = GraphLayoutCoordinator<FSAState>()
    @State private var algorithm: FfiAlgorithm = .brandesKopf
    @State private var anchor: GraphAnchor = .center

    var body: some View {
        VStack {
            Picker("Algorithm", selection: $algorithm) {
                Text("Median Relax").tag(FfiAlgorithm.medianRelax)
                Text("Brandes-Köpf").tag(FfiAlgorithm.brandesKopf)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            AnchorPicker(anchor: $anchor)

            // Not using `AnchoredGraphView` here: the transition-symbol and
            // self-loop overlays below draw at raw (un-anchored) node/route
            // coordinates too, as ZStack siblings of the graph itself. They
            // need the exact same offset the graph gets, so the offset is
            // computed once here and applied to all three together, rather
            // than letting the graph anchor itself in isolation.
            // Translate the drawing context inside the Canvas (or pass the
            // placement offset into GraphVisualizationView) so all strokes
            // occur in positive canvas space
            // $[0 \dots \text{width}, 0 \dots \text{height}]$:
            GeometryReader { proxy in
                let offset = GraphPlacement.offset(
                    boundingBox: coordinator.boundingBox,
                    canvasSize: proxy.size,
                    anchor: anchor
                )
                ZStack {
                    GraphVisualizationView(coordinator: coordinator, offset: offset) { state in
                        AnyView(FSANodeView(state: state))
                    }
                    transitionSymbolOverlay(offset: offset)
                    selfLoopOverlay(offset: offset)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .animation(.easeInOut(duration: 0.2), value: offset)
            }
        }
        .task { await runLayout() }
        .onChange(of: algorithm) { _, _ in Task { await runLayout() } }
    }

    /// Labels each rendered edge with its transition symbol, looked up by
    /// mapping the route's FFI ids back to the original `FSAState`s via
    /// `coordinator.nodes` — no change to the shared flattener/coordinator
    /// needed for this.
    ///
    /// Prefers `route.labelPosition` — the engine's own obstacle-free
    /// placement, computed from the `labelWidth`/`labelHeight` every edge
    /// gets in `FSAFlattener.flatten()` — over eyeballing a point from the
    /// polyline/curve. Falls back to the old midpoint heuristic only if a
    /// route somehow lacks one (e.g. label dimensions weren't supplied).
    private func transitionSymbolOverlay(offset: CGSize) -> some View {
        let byId = Dictionary(uniqueKeysWithValues: coordinator.nodes.map { ($0.id, $0.source) })
        return ForEach(coordinator.routes) { route in
            if let from = byId[route.from], let to = byId[route.to] {
                let matching = from.transitions.filter { $0.target === to }.map(\.symbol)
                let symbolText = matching.joined(separator: ", ")
                let labelPoint = route.labelPosition ?? route.points.dropFirst(route.points.count / 2).first
                if !symbolText.isEmpty, let point = labelPoint {
                    Text(symbolText)
                        .font(.caption2.monospaced())
                        .padding(2)
                        .background(.background, in: RoundedRectangle(cornerRadius: 3))
                        .position(x: point.x + offset.width, y: point.y + offset.height)
                }
            }
        }
    }

    /// Self-loop transitions (e.g. q0 --b--> q0) get pulled out of the
    /// main layout by `LayoutGraph::extract_self_loops` on the Rust side
    /// and never appear in `coordinator.routes` — they come back
    /// separately as `coordinator.selfLoops`. Draw a small loop glyph
    /// above each node that has one, labeled with its symbol(s).
    ///
    /// Takes the same placement `offset` as `transitionSymbolOverlay` and
    /// applies it the same way — these glyphs are positioned from raw
    /// node coordinates, so without it they'd drift out of alignment with
    /// the (offset) graph as soon as `anchor` isn't `.center`.
    private func selfLoopOverlay(offset: CGSize) -> some View {
        let byId = Dictionary(uniqueKeysWithValues: coordinator.nodes.map { ($0.id, $0) })
        let symbolsById: [UInt64: [String]] = Dictionary(
            grouping: coordinator.selfLoops.compactMap { loop -> (UInt64, String)? in
                guard let state = byId[loop.from]?.source else { return nil }
                let symbol = state.transitions.first(where: { $0.target === state })?.symbol ?? "?"
                return (loop.from, symbol)
            },
            by: { $0.0 }
        ).mapValues { $0.map(\.1) }

        return ForEach(Array(symbolsById.keys), id: \.self) { id in
            if let node = byId[id] {
                VStack(spacing: 1) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text(symbolsById[id]?.joined(separator: ",") ?? "")
                        .font(.caption2.monospaced())
                }
                .padding(3)
                .background(.background, in: RoundedRectangle(cornerRadius: 4))
                .position(x: node.x + offset.width, y: node.y - 40 + offset.height)
            }
        }
    }

    private func runLayout() async {
        let flattener = FSAFlattener(states: states) { measureLabel($0) }
        let config = FfiConfig(
                        hGap: 32,
                        vGap: 56,
                        relaxPasses: 4,
                        sweeps: 4,
                        algorithm: algorithm,
                        routing: .bezier,
                        direction: .leftToRight
                    )
        await coordinator.relayout(flattener, config: config)
    }
}

// MARK: - SPPF

private struct SPPFNodeView: View {
    let node: SPPFNode
    var body: some View {
        Group {
            if node.isPacked {
                Text(node.label)
                    .font(.caption2.monospaced())
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.orange.opacity(0.15))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.orange))
            } else {
                Text(node.label)
                    .font(.callout.monospaced())
                    .padding(8)
                    .background(Circle().fill(.blue.opacity(0.12)))
                    .overlay(Circle().stroke(.blue))
            }
        }
    }
}

struct SPPFContainerView: View {
    let roots: [SPPFNode]
    @StateObject private var coordinator = GraphLayoutCoordinator<SPPFNode>()
    @State private var algorithm: FfiAlgorithm = .brandesKopf
    @State private var anchor: GraphAnchor = .center

    var body: some View {
        VStack {
            Picker("Algorithm", selection: $algorithm) {
                Text("Median Relax").tag(FfiAlgorithm.medianRelax)
                Text("Brandes-Köpf").tag(FfiAlgorithm.brandesKopf)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            AnchorPicker(anchor: $anchor)

            Text("Blue = symbol node, orange = packed node (one derivation). Fan-in shows sharing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            AnchoredGraphView(coordinator: coordinator, anchor: anchor) { node in
                AnyView(SPPFNodeView(node: node))
            }
        }
        .task { await runLayout() }
        .onChange(of: algorithm) { _, _ in Task { await runLayout() } }
    }

    private func runLayout() async {
        let flattener = SPPFFlattener(roots: roots) { measureLabel($0) }
        let config = FfiConfig(
                        hGap: 20,
                        vGap: 48,
                        relaxPasses: 4,
                        sweeps: 4,
                        algorithm: algorithm,
                        routing: .bezier,
                        direction: .topToBottom
                    )
        await coordinator.relayout(flattener, config: config)
    }
}

// MARK: - GSS

private struct GSSNodeView: View {
    let node: GSSNode
    var body: some View {
        Text(node.label)
            .font(.caption2.monospaced())
            .multilineTextAlignment(.center)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.green))
    }
}

struct GSSContainerView: View {
    let nodes: [GSSNode]
    @StateObject private var coordinator = GraphLayoutCoordinator<GSSNode>()
    @State private var algorithm: FfiAlgorithm = .brandesKopf
    @State private var anchor: GraphAnchor = .center

    var body: some View {
        VStack {
            Picker("Algorithm", selection: $algorithm) {
                Text("Median Relax").tag(FfiAlgorithm.medianRelax)
                Text("Brandes-Köpf").tag(FfiAlgorithm.brandesKopf)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            AnchorPicker(anchor: $anchor)

            Text("v3 has two predecessors — a merge, not a tree edge.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            AnchoredGraphView(coordinator: coordinator, anchor: anchor) { node in
                AnyView(GSSNodeView(node: node))
            }
        }
        .task { await runLayout() }
        .onChange(of: algorithm) { _, _ in Task { await runLayout() } }
    }

    private func runLayout() async {
        let flattener = GSSFlattener(nodes: nodes) { measureLabel($0) }
        let config = FfiConfig(
                        hGap: 28,
                        vGap: 52,
                        relaxPasses: 4,
                        sweeps: 4,
                        algorithm: algorithm,
                        routing: .bezier,
                        direction: .leftToRight
                    )
        await coordinator.relayout(flattener, config: config)
    }
}
