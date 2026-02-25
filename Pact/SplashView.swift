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
    @State private var hasFinished = false

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

            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .scaleEffect(logoScale)
                .offset(y: logoOffsetY)
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
                logoOffsetY = 0
            }
        }

        // Transition out after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard !hasFinished else { return }
            hasFinished = true
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
