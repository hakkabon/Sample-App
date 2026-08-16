/*

// 1. Drawing the Arrowhead (Filled Polygon)
if let ah = route.arrowhead {
    Path { path in
        path.move(to: CGPoint(x: ah.left.x, y: ah.left.y))
        path.addLine(to: CGPoint(x: ah.tip.x, y: ah.tip.y))
        path.addLine(to: CGPoint(x: ah.right.x, y: ah.right.y))
        path.closeSubpath()
    }
    .fill(Color.primary) // Or your edge color
}

// 2. Positioning the Label smoothly
if let pos = route.label_position {
    Text("transition_symbol")
        .padding(4)
        .background(Color.systemBackground) // Optional: hide the line behind the text
        .position(x: pos.x, y: pos.y)
}

*/
