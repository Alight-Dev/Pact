//
//  SplashView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

struct SplashView: View {
    var onFinished: () async -> Void
    var onSkipToSignup: (() -> Void)? = nil

    @State private var logoScale: CGFloat = 0.3
    @State private var logoOffsetY: CGFloat = 1000 // Will be set properly in onAppear
    @State private var showTagline = false
    @State private var showButton = false
    @State private var textHighlightVisible = false
    @State private var screenHeight: CGFloat = 1000
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            // Skip button — top right, for testing only
            if let skipAction = onSkipToSignup {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: skipAction) {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                        .overlay(
                                            Capsule().strokeBorder(Color.black.opacity(0.10), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }

            // Logo — comes to rest in the upper-middle of the screen
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .scaleEffect(logoScale)
                .offset(y: logoOffsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Tagline + supporting copy — sits around the vertical middle, slightly lower
            if showTagline {
                VStack(spacing: 10) {
                    VStack(spacing: 6) {
                        Text("Protect your focus.\nTogether.")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("Lock distractions until your team agrees you’re done.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(white: 0.4))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.97),
                                        Color(white: 0.93)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(x: textHighlightVisible ? 1 : 0,
                                         y: 1,
                                         anchor: .leading)
                    )
                    .padding(.horizontal, 32)
                }
                // Slightly below vertical center so the logo can live above it
                .offset(y: 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            // Button — appears from the bottom after the text highlight
            if showButton {
                VStack {
                    Spacer()
                    Button {
                        isLoading = true
                        Task { await onFinished() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Get Started")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                        )
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
        // Reset state
        showTagline = false
        showButton = false
        textHighlightVisible = false
        logoScale = 0.3
        logoOffsetY = screenHeight

        // Phase 1: Scale up with overshoot and move from off-screen bottom toward upper-middle
        withAnimation(.interpolatingSpring(stiffness: 140, damping: 16)) {
            logoScale = 1.35
            logoOffsetY = -160
        }

        // Phase 2: Settle to final scale and position (center)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.88, blendDuration: 0.25)) {
                logoScale = 1.25
                logoOffsetY = -120
            }
        }

        // Phase 3: Reveal tagline
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.45)) {
                showTagline = true
            }
        }

        // Phase 4: Highlight sweep under main line
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
            withAnimation(.easeOut(duration: 0.6)) {
                textHighlightVisible = true
            }
        }

        // Phase 5: Reveal CTA button
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.9, blendDuration: 0.25)) {
                showButton = true
            }
        }
    }


}

#Preview {
    SplashView(onFinished: {})
}
