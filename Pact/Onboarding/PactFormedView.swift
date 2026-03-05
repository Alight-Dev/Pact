//
//  PactFormedView.swift
//  Pact
//

import SwiftUI

/// Full-screen celebration shown when everyone has agreed and the Pact is activated.
/// Shown as an interrupt from ForgePactView or HomeScreenView.
struct PactFormedView: View {
    var onDismiss: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.7
    @State private var subtitleOpacity: Double = 0
    @State private var showContinue = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("The Pact is Formed")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)
                    .scaleEffect(titleScale)

                Text("Everyone has agreed. The challenge starts now.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .opacity(subtitleOpacity)

                Spacer(minLength: 0)

                if showContinue {
                    Button(action: onDismiss) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                titleOpacity = 1
                titleScale = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                subtitleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.7)) {
                showContinue = true
            }
        }
    }
}

#Preview {
    PactFormedView(onDismiss: {})
}
