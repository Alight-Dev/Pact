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
    @State private var logoOffsetY: CGFloat = 1000 // Will be set properly in onAppear
    @State private var showOnboardingContent = false
    @State private var screenHeight: CGFloat = 1000

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            // Centered logo that animates independently of the text/button
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .scaleEffect(logoScale)
                .offset(y: logoOffsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Text + button anchored to the bottom, appearing after animation
            if showOnboardingContent {
                VStack(spacing: 16) {
                    Spacer()

                    Text("Where you and your team will\nmake the most of your goals")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(white: 0.22))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)

                    Button(action: onFinished) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black)
                            )
                    }
                    .padding(.horizontal, 24)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        screenHeight = geometry.size.height
                        if logoOffsetY == 1000 {
                            logoOffsetY = screenHeight
                        }
                    }
            }
        }
    }

    private func startAnimationSequence() {
        showOnboardingContent = false

        // Phase 1: Scale up with overshoot and move from off-screen bottom toward center
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 14)) {
            logoScale = 1.2
            logoOffsetY = -40
        }

        // Phase 2: Settle to final scale and position (center)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.2)) {
                logoScale = 1.0
                logoOffsetY = 0
            }
        }

        // Reveal onboarding text and button after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showOnboardingContent = true
            }
        }
    }


}

#Preview {
    SplashView(onFinished: {})
}
