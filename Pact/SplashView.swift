//
//  SplashView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.3
    @State private var logoOffsetY: CGFloat = 300
    @State private var showOnboardingContent = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white,
                    Color(red: 0.671, green: 0.608, blue: 0.984) // #AB9BFB
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(logoScale)
                    .offset(y: logoOffsetY)
                    .padding(.bottom, showOnboardingContent ? 24 : 0)

                if showOnboardingContent {
                    Text("Where you and your team will\nmake the most of your goals")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Spacer()

                    Button(action: onFinished) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.93, green: 0.92, blue: 0.87))
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Phase 1: Scale up with overshoot and lift toward center
        withAnimation(.easeOut(duration: 1.2)) {
            logoScale = 1.2
            logoOffsetY = -20
        }

        // Phase 2: Settle to final scale and position
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.6)) {
                logoScale = 1.0
                logoOffsetY = -20
            }
        }

        // Reveal onboarding text and button after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showOnboardingContent = true
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
