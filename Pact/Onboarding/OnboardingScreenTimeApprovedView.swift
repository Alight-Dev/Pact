//
//  OnboardingScreenTimeApprovedView.swift
//  Pact
//
//  Light-themed confirmation screen shown after
//  Screen Time access has been approved.
//

import SwiftUI

struct OnboardingScreenTimeApprovedView: View {
    var onBack: (() -> Void)?
    var onContinue: () -> Void

    private let totalSteps = 8
    private let currentStep = 6

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Navigation row
                HStack(alignment: .center) {
                    if let onBack {
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
                    } else {
                        Color.clear
                            .frame(width: 40, height: 40)
                    }

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

                // MARK: Center content
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(red: 0.97, green: 0.97, blue: 0.99))
                            .frame(width: 140, height: 140)
                            .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 12)

                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 86, height: 86)
                    }

                    VStack(spacing: 8) {
                        Text("Pact is connected to Screen Time")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)

                        Text("Pact can now lock the apps you choose until you’ve forged today’s shield.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                // MARK: Continue button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    OnboardingScreenTimeApprovedView(
        onBack: {},
        onContinue: {}
    )
}

