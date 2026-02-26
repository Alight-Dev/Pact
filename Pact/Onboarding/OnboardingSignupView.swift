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

    private let totalSteps = 8
    private let currentStep = 6

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
                                AsyncImage(url: URL(string: "https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png")) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    Color.clear
                                }
                                .frame(width: 22, height: 22)
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

// MARK: - Previews

#Preview("OnboardingSignupView") {
    OnboardingSignupView(onBack: {}, onContinue: {})
}
