//
//  HelperViews.swift
//  Sample-App
//
//  Created by Ulf Akerstedt-Inoue on 2026/08/14.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import SwiftUI
import SwiftLayout

/// Small reusable segmented control for the four container views to pick
/// an anchor interactively — purely a demo convenience.
public struct AnchorPicker: View {
    @Binding var anchor: GraphAnchor
    public var body: some View {
        Picker("Anchor", selection: $anchor) {
            ForEach(GraphAnchor.allCases) { a in
                Text(a.rawValue).tag(a)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
