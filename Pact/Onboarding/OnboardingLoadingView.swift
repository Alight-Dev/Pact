//
//  OnboardingLoadingView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/26/26.
//

import SwiftUI

struct OnboardingLoadingView: View {
    var onFinished: () -> Void

    @State private var isAnimating = false

    private let dotCount = 5
    private let dotSize: CGFloat = 14

    var body: some View {
        ZStack {
            Color(white: 0.97).ignoresSafeArea()

            VStack(spacing: 28) {
                HStack(spacing: 10) {
                    ForEach(0..<dotCount, id: \.self) { i in
                        Circle()
                            .fill(Color.black)
                            .frame(width: dotSize, height: dotSize)
                            .scaleEffect(isAnimating ? 0.4 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                value: isAnimating
                            )
                    }
                }

                Text("Calculating...")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
            }
        }
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onFinished()
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    OnboardingLoadingView(onFinished: {})
}
