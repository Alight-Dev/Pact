//
//  OnboardingCreateOrJoinSheildView.swift
//  Pact
//
//  Created by Cursor on 2/25/26.
//

import SwiftUI

struct OnboardingCreateOrJoinShieldView: View {
    var onCreateShield: () -> Void
    var onJoinShield: () -> Void
    var onSkip: (() -> Void)? = nil

    @State private var logoScale: CGFloat = 0.4
    @State private var logoOffsetY: CGFloat = 260
    @State private var showContent: Bool = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .scaleEffect(logoScale)
                    .offset(y: logoOffsetY)

                if showContent {
                    VStack(spacing: 6) {
                        Text("One more step.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.55))

                        Text("How do you want\nto start?")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    // Cards
                    VStack(spacing: 14) {
                        // Create a Shield — dark card
                        Button(action: onCreateShield) {
                            VStack(alignment: .leading, spacing: 0) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(white: 0.25))
                                    )

                                Spacer(minLength: 0)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Create a Shield")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(.white)

                                    Text("Build a team and set the rules")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(white: 0.6))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 150)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.black)
                            )
                        }
                        .buttonStyle(.plain)

                        // Join a Shield — light card
                        Button(action: onJoinShield) {
                            VStack(alignment: .leading, spacing: 0) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.black)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                                    )

                                Spacer(minLength: 0)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Join a Shield")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(.black)

                                    Text("Use an invite code from your team")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(white: 0.55))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 150)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color(white: 0.97))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .strokeBorder(Color.black, lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Text("Pact works best with 2–5 friends")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.65))
                        .padding(.top, 20)
                        .transition(.opacity)

                    if let onSkip {
                        Button(action: onSkip) {
                            Text("Skip for now")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(white: 0.55))
                        }
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
        .preferredColorScheme(.light)
    }

    private func startAnimation() {
        logoScale = 0.4
        logoOffsetY = 260
        showContent = false

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
                withAnimation(.easeInOut(duration: 0.4)) {
                    showContent = true
                }
            }
        }
    }
}

#Preview {
    OnboardingCreateOrJoinShieldView(
        onCreateShield: {},
        onJoinShield: {}
    )
}
