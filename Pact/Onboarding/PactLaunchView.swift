//
//  PactLaunchView.swift
//  Pact
//
//

import SwiftUI

struct PactLaunchView: View {
    let onFinished: () -> Void

    @State private var animate = false
    @State private var hasScheduledFinish = false
    @State private var contentOpacity: CGFloat = 0
    @State private var contentOffset: CGFloat = 40
    @State private var burstScale: CGFloat = 0.3
    @State private var burstOpacity: CGFloat = 1.0

    private let maroon = Color(red: 0.55, green: 0.0, blue: 0.15)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(white: 0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Expanding glow that creates a dramatic full-screen takeover
            Circle()
                .fill(maroon.opacity(0.16))
                .frame(width: 520, height: 520)
                .scaleEffect(burstScale)
                .opacity(burstOpacity)
                .blur(radius: 40)
                .offset(y: 260)

            VStack(spacing: 28) {
                Spacer()

                // Badge
                Text("Your pact is ready")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(maroon.opacity(0.08))
                    )
                    .foregroundStyle(maroon)

                // Headline
                Text("Reach your focus goals")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.black)

                // Subcopy
                Text("You’ve set your daily pact. We’ll keep you accountable.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Animated logo / shield cluster
                ZStack {
                    // Glowing maroon halo
                    Circle()
                        .fill(maroon.opacity(0.10))
                        .frame(width: 220, height: 220)
                        .scaleEffect(animate ? 1.05 : 0.98)
                        .animation(
                            .easeInOut(duration: 1.6)
                                .repeatForever(autoreverses: true),
                            value: animate
                        )

                    // Center logo
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)

                    // Floating side cards / hearts
                    FloatingPill(
                        systemIcon: "heart.fill",
                        offsetX: -90,
                        baseOffsetY: -40,
                        amplitude: 10,
                        tint: maroon,
                        animate: animate
                    )

                    FloatingPill(
                        systemIcon: "shield.lefthalf.filled",
                        offsetX: 90,
                        baseOffsetY: 30,
                        amplitude: 8,
                        tint: .black,
                        animate: animate
                    )
                }
                .padding(.top, 20)

                LoadingDotsView(color: maroon)
                    .padding(.top, 8)

                Spacer()
            }
            .padding(.bottom, 80)
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .onAppear {
            animate = true
            withAnimation(
                .spring(response: 0.7, dampingFraction: 0.9, blendDuration: 0.2)
            ) {
                contentOpacity = 1
                contentOffset = 0
            }

            withAnimation(
                .easeOut(duration: 1.4)
            ) {
                burstScale = 1.15
                burstOpacity = 0
            }

            scheduleAutoAdvance()
        }
    }

    private func scheduleAutoAdvance() {
        guard !hasScheduledFinish else { return }
        hasScheduledFinish = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onFinished()
        }
    }
}

// MARK: - Floating Pill

private struct FloatingPill: View {
    let systemIcon: String
    let offsetX: CGFloat
    let baseOffsetY: CGFloat
    let amplitude: CGFloat
    let tint: Color
    let animate: Bool

    var body: some View {
        let yOffset = animate ? baseOffsetY - amplitude : baseOffsetY + amplitude

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(white: 0.97))
            .frame(width: 80, height: 48)
            .overlay {
                Image(systemName: systemIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
            .offset(x: offsetX, y: yOffset)
            .rotationEffect(.degrees(animate ? -6 : 4))
            .animation(
                .easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: true),
                value: animate
            )
    }
}

// MARK: - Loading Dots

private struct LoadingDotsView: View {
    let color: Color

    @State private var animate = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                let delay = Double(index) * 0.16

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .opacity(animate ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Preview

#Preview {
    PactLaunchView(onFinished: {})
}

