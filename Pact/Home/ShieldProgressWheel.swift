//
//  ShieldProgressWheel.swift
//  Pact
//

import SwiftUI

struct ShieldProgressWheel: View {

    @ObservedObject var viewModel: ShieldProgressViewModel

    @State private var animatedProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    private let ringDiameter: CGFloat = 140
    private let ringWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: 20) {
            // Ring + center text
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color(white: 0.90), lineWidth: ringWidth)
                    .frame(width: ringDiameter, height: ringDiameter)

                // Progress arc
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        Color.black,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text("\(viewModel.streakDays)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)

                    Text("Day Streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                }
            }
            .scaleEffect(pulseScale)

            // Tier info
            VStack(spacing: 6) {
                Text(viewModel.currentTier.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                if viewModel.isMaxTier {
                    Text("Max Tier Achieved")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                } else if viewModel.currentTier == .none {
                    Text("Start your streak to earn a rank")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                } else if let next = viewModel.nextTier {
                    Text("\(viewModel.daysUntilNextTier) days until \(next.rawValue)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.96))
        )
        .onChange(of: viewModel.progressToNextTier) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: viewModel.tierJustUnlocked) { _, unlocked in
            if unlocked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    pulseScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        pulseScale = 1.0
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = viewModel.progressToNextTier
            }
        }
    }
}

#Preview {
    let vm = ShieldProgressViewModel()
    ShieldProgressWheel(viewModel: vm)
        .padding(20)
}
