# Sample-App

A SwiftUI app demonstrating [`Swift-Layout`](https://github.com/hakkabon/Swift-Layout)
— the Swift wrapper around the [`Layout`](https://github.com/hakkabon/Layout) Rust
graph layout engine — against four different kinds of graph. It exists to answer
"what does actually using this package look like," not as a product in its own
right: every container view below is a template for wiring up one more graph kind.

## What's on screen

`GraphGalleryView` is a picker over four example graphs, each rendered through
the same `GraphLayoutCoordinator` → `AnchoredGraphView` pipeline — only the
`GraphFlattening` conformance and the per-node SwiftUI content differ:

| Graph kind | Container view | What it shows |
|---|---|---|
| Syntax Tree | `SyntaxTreeContainerView` | A plain tree, top-to-bottom, Bézier-routed edges. Both layout algorithms (Median-Relax / Brandes-Köpf) selectable live. |
| FSA / DFA | `FSAContainerView` | A finite-state automaton, including self-loop transitions (e.g. `q0 --b--> q0`) and multiple transitions between the same pair of states. |
| SPPF | `SPPFContainerView` | A Shared Packed Parse Forest — a DAG, not a tree, with genuine node sharing across derivations and ambiguity (multiple packed-node children). |
| GSS | `GSSContainerView` | A Graph-Structured Stack — another DAG, built in push order (predecessor → node), demonstrating merged/fan-in nodes. |

Each container view also exposes an algorithm picker (where applicable) and a
`GraphAnchor` picker (`AnchorPicker`), so you can see the same graph re-laid-out
or re-anchored without touching code.

## Structure

```
Sample-App/
├── Sample_App.swift          — @main entry point
├── ContentView.swift         — hosts GraphGalleryView
├── GraphGallery.swift        — the picker + all four container views
├── SampleGraphs.swift        — hand-built sample data for all four graph kinds
├── HelperViews.swift         — AnchorPicker, shared across container views
└── GraphFlattening/
    ├── CST-Flattening.swift  — SyntaxTreeFlattener (plain tree)
    ├── FSA-Flattening.swift  — FSAFlattener (states + labeled transitions)
    ├── SPPF-Flattening.swift — SPPFFlattener (shared DAG)
    └── GSS-Flattening.swift  — GSSFlattener (merged-DAG, push order)
```

If you're adding a fifth graph kind, `GraphFlattening/` is the pattern to copy:
define a minimal domain model for that graph, a `GraphFlattening` conformance
that walks it into `FfiNode`/`FfiEdge`, and a container view in
`GraphGallery.swift` following the same `@StateObject coordinator` +
`.task`/`.onChange` → `relayout` shape as the existing four. See
`Swift-Layout`'s README for what each piece of that pipeline actually does.

## Running it

1. Open the project in Xcode.
2. The project depends on the `Swift-Layout` Swift package, which in turn pulls
   a prebuilt `LayoutFFI.xcframework` binary from `Layout`'s GitHub releases —
   Xcode resolves this automatically on first build, no local Rust toolchain
   needed.
3. Build and run on any of the platforms `Swift-Layout` supports (iOS, macOS,
   Mac Catalyst).

## Notes for anyone extending this

- **Node identity matters for smooth relayout.** `GraphFlattening.flatten()`
  should discover nodes in deterministic order (iterate arrays, not `Set`s) —
  see the `NodeIDAllocator` note in `Swift-Layout`'s README. All four flatteners
  here do this; keep it that way if you add a fifth.
- **Self-loops don't come back through `coordinator.routes`.** They're pulled
  out separately as `coordinator.selfLoops`; `FSAContainerView`'s
  `selfLoopOverlay` is the reference implementation for rendering them (a small
  glyph + label positioned above the node, offset-aware).
- **Edge labels use the engine's `labelPosition`, not a guessed midpoint** —
  see `transitionSymbolOverlay` in `FSAContainerView` for the pattern: prefer
  `route.labelPosition`, fall back to eyeballing a point from `route.points`
  only if a route has none.
