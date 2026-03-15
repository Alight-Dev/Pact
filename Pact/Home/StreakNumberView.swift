//
//  StreakNumberView.swift
//  Pact
//
//  Animated count-up streak number with warm gold gradient.
//

import SwiftUI

struct StreakNumberView: View {
    let targetStreak: Int
    var fontSize: CGFloat = 160

    @State private var displayed: Int = 0
    @State private var hasAppeared = false

    var body: some View {
        Text("\(displayed)")
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .foregroundStyle(LinearGradient.pactGold)
            .contentTransition(.numericText(countsDown: false))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                animateCountUp()
            }
            .onChange(of: targetStreak) { _, new in
                displayed = new
            }
    }

    private func animateCountUp() {
        guard targetStreak > 0 else {
            displayed = 0
            return
        }
        // Count from 0 to targetStreak over ~0.8s
        let steps = min(targetStreak, 30)
        let duration: Double = 0.8
        let stepDelay = duration / Double(steps)

        for i in 0...steps {
            let fraction = Double(i) / Double(steps)
            // easeOut curve: value grows fast at start, slows at end
            let eased = 1 - pow(1 - fraction, 3)
            let value = Int(round(eased * Double(targetStreak)))
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay * Double(i)) {
                withAnimation(.easeOut(duration: stepDelay)) {
                    displayed = value
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.pactBackground.ignoresSafeArea()
        StreakNumberView(targetStreak: 12)
    }
}
