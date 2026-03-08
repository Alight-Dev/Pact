//
//  BlobBackground.swift
//  Pact
//
//  Animated mesh-gradient background.
//  Interior control points drift slowly so the colour blobs breathe and flow.
//

import SwiftUI

// MARK: - BlobBackground

struct BlobBackground: View {

    /// Drives the mesh-point animation. Toggled once on appear;
    /// the animation repeats forever with autoreversal.
    @State private var animating = false

    // MARK: Animated mesh control points
    //
    // Edge points (row 0, row 4, col 0, col 2) are fixed so they never clip.
    // The three interior mid-column points drift gently in opposite phase
    // to each other, giving the blobs an organic, breathing quality.

    private var meshPoints: [SIMD2<Float>] {
        [
            // Row 0 — top edge (fixed)
            [0, 0],   [0.5, 0],   [1, 0],

            // Row 1 — left/right edges fixed, mid drifts right↔left + up↔down
            [0, 0.25],
            [animating ? 0.42 : 0.58,  animating ? 0.22 : 0.28],
            [1, 0.25],

            // Row 2 — mid drifts opposite direction to row 1
            [0, 0.5],
            [animating ? 0.56 : 0.44,  0.5],
            [1, 0.5],

            // Row 3 — mid drifts with row 1 but smaller amplitude
            [0, 0.75],
            [animating ? 0.46 : 0.54,  animating ? 0.73 : 0.77],
            [1, 0.75],

            // Row 4 — bottom edge (fixed)
            [0, 1],   [0.5, 1],   [1, 1],
        ]
    }

    var body: some View {
        ZStack {
            // White base so nothing bleeds through on older hardware
            Color.white.ignoresSafeArea()

            MeshGradient(
                width: 3,
                height: 5,
                points: meshPoints,
                colors: [
                    // Row 0 — blue tint · lavender · warm yellow
                    Color(red: 0.856, green: 0.886, blue: 0.996),
                    Color(red: 0.925, green: 0.910, blue: 0.996),
                    Color(red: 0.993, green: 0.929, blue: 0.804),

                    // Row 1 — mirrors row 0 so the top blob stays vivid
                    Color(red: 0.856, green: 0.886, blue: 0.996),
                    Color(red: 0.925, green: 0.910, blue: 0.996),
                    Color(red: 0.993, green: 0.929, blue: 0.804),

                    // Rows 2-4 — fade out to near-white
                    Color(red: 0.978, green: 0.980, blue: 1.000), .white, Color(red: 1.000, green: 0.978, blue: 0.976),
                    Color(red: 0.978, green: 0.980, blue: 1.000), .white, Color(red: 1.000, green: 0.978, blue: 0.976),
                    Color(red: 0.978, green: 0.980, blue: 1.000), .white, Color(red: 1.000, green: 0.978, blue: 0.976),
                ]
            )
            .ignoresSafeArea()
            // Slow, eased loop — autoreverses so the movement is seamless
            .animation(
                .easeInOut(duration: 6).repeatForever(autoreverses: true),
                value: animating
            )
        }
        .overlay(Grain().ignoresSafeArea())
        .onAppear { animating = true }
    }
}

// MARK: - Grain

/// Film-grain overlay: rapidly swaps random noise dots via TimelineView.
/// Uses .overlay blend mode so it adds texture without darkening.
struct Grain: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { _ in
            Canvas { context, size in
                for _ in 0..<40_000 {
                    let x       = CGFloat.random(in: 0...size.width)
                    let y       = CGFloat.random(in: 0...size.height)
                    let dotSize = CGFloat.random(in: 0.5...1.5)
                    let rect    = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Path(rect),
                        with: .color(.black.opacity(Double.random(in: 0.04...0.18)))
                    )
                }
            }
        }
        .blendMode(.overlay)
        .opacity(0.65)
    }
}
