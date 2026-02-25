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
    @State private var logoOffsetY: CGFloat = 400
    @State private var showOnboardingContent = false

    var body: some View {
        ZStack {


            GeometryReader { proxy in
                ZStack {
                    // Centered logo that animates independently of the text/button
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .scaleEffect(logoScale)
                        .offset(y: logoOffsetY)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    // Text + button anchored to the bottom, appearing after animation
                    if showOnboardingContent {
                        VStack(spacing: 16) {
                            Spacer()

                            Text("Where you and your team will\nmake the most of your goals")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)

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
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Phase 1: Scale up with overshoot and move from off-screen bottom toward center
        withAnimation(.easeOut(duration: 1.0)) {
            logoScale = 1.2
            logoOffsetY = -40
        }

        // Phase 2: Settle to final scale and position (center)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2)) {
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
