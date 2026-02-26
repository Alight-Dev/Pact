//
//  OnboardingSignupView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

struct OnboardingSignupView: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var logoOffsetY: CGFloat = 0
    @State private var logoSize: CGFloat = 210      // 150 × 1.4
    @State private var showContent: Bool = false
    @State private var screenHeight: CGFloat = 1000

    private let totalSteps = 5
    private let currentStep = 2

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // MARK: Logo — always present, rises from center to upper-middle
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .offset(y: logoOffsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // MARK: Nav + content — fades in after logo settles
            if showContent {
                VStack(spacing: 0) {

                    // MARK: Navigation row
                    HStack(alignment: .center) {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                        .overlay(
                                            Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                        )
                                )
                        }
                        .accessibilityLabel("Go back")

                        OnboardingProgressBar(totalSteps: totalSteps, currentStep: currentStep)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)

                        HStack(spacing: 4) {
                            Text("🇺🇸")
                                .font(.system(size: 14))
                            Text("EN")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                .overlay(
                                    Capsule().strokeBorder(Color.black.opacity(0.10), lineWidth: 1)
                                )
                        )
                        .accessibilityLabel("Language: English")
                        .accessibilityAddTraits(.isButton)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer()

                    // MARK: Title
                    VStack(spacing: 6) {
                        Text("Join")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(Color(white: 0.55))

                        Text("Pact")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.black)
                    }

                    Spacer()

                    // MARK: Signup buttons
                    VStack(spacing: 14) {

                        // Continue with Apple
                        Button(action: onContinue) {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Continue with Apple")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Capsule().fill(Color.black))
                        }

                        // Continue with Google
                        Button(action: onContinue) {
                            HStack(spacing: 10) {
                                GoogleLogoView(size: 22)
                                Text("Continue with Google")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Capsule().fill(Color.white))
                            .overlay(Capsule().stroke(Color(white: 0.82), lineWidth: 1.5))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear {
                    screenHeight = geometry.size.height
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .preferredColorScheme(.light)
    }

    private func startAnimation() {
        // Phase 1: Logo rises to upper-middle after slide-in transition completes (~0.35s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let midOffset = -(screenHeight * 0.20)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                logoOffsetY = midOffset
                logoSize = 126                  // 90 × 1.4
            }
        }
        // Phase 2: Nav bar, title, and buttons fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showContent = true
            }
        }
    }
}

// MARK: - Google Logo

private struct GoogleLogoView: View {
    let size: CGFloat

    private let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)  // #4285F4
    private let red    = Color(red: 0.918, green: 0.263, blue: 0.208)  // #EA4335
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.020)  // #FBBC05
    private let green  = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853

    private var lw: CGFloat { size * 0.22 }

    var body: some View {
        ZStack {
            // Four coloured arc segments (clockwise from 12 o'clock)
            arc(from: 0.000, to: 0.250, color: red)      // top
            arc(from: 0.250, to: 0.375, color: yellow)    // upper-right
            arc(from: 0.375, to: 0.556, color: green)     // lower-right
            arc(from: 0.556, to: 1.000, color: blue)      // bottom-left

            // White mask — opens the right side of the ring to form the G gap
            Rectangle()
                .fill(Color.white)
                .frame(width: size * 0.50, height: lw)
                .offset(x: size * 0.25)

            // Blue crossbar — horizontal stroke of the G
            Rectangle()
                .fill(blue)
                .frame(width: size * 0.50, height: lw)
                .offset(x: size * 0.25)
        }
        .frame(width: size, height: size)
    }

    private func arc(from start: CGFloat, to end: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .frame(width: size - lw, height: size - lw)
    }
}

// MARK: - Preview

#Preview {
    OnboardingSignupView(onBack: {}, onContinue: {})
}

#Preview("Google Logo") {
    GoogleLogoView(size: 80)
        .padding()
}
