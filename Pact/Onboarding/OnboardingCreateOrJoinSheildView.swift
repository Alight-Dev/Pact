//
//  OnboardingCreateOrJoinSheildView.swift
//  Pact
//
//  Created by Cursor on 2/25/26.
//

import SwiftUI

struct OnboardingCreateOrJoinSheildView: View {
    var onCreateShield: () -> Void
    var onJoinShield: () -> Void
    var onNoAccount: () -> Void

    @State private var logoScale: CGFloat = 0.4
    @State private var logoOffsetY: CGFloat = 260
    @State private var showOptions: Bool = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(logoScale)
                    .offset(y: logoOffsetY)

                if showOptions {
                    VStack(spacing: 24) {
                        HStack(spacing: 16) {
                            Button(action: onCreateShield) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Create a Shield")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.black)

                                    Text("Start a new team")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(white: 0.55))
                                }
                                .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(white: 0.96))
                                )
                            }
                            .buttonStyle(.plain)

                            Button(action: onJoinShield) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Join a Shield")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.black)

                                    Text("Use an invite link")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(white: 0.55))
                                }
                                .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(white: 0.96))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        logoScale = 0.4
        logoOffsetY = 260
        showOptions = false

        withAnimation(.interpolatingSpring(stiffness: 180, damping: 14)) {
            logoScale = 1.1
            logoOffsetY = -12
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.2)) {
                logoScale = 1.0
                logoOffsetY = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showOptions = true
                }
            }
        }
    }
}

#Preview {
    OnboardingCreateOrJoinSheildView(
        onCreateShield: {},
        onJoinShield: {},
        onNoAccount: {}
    )
}

