//
//  OnboardingScreenTimeAccessIntroView.swift
//  Pact
//
//  Light-themed explainer screen prompting users
//  to connect Pact to Screen Time, strongly recommended
//  but skippable.
//

import FamilyControls
import SwiftUI

struct OnboardingScreenTimeAccessIntroView: View {
    var onBack: (() -> Void)?
    var onConnectTapped: () -> Void
    var onSkipTapped: () -> Void

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
                        // Keep layout stable when no back button
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

                // MARK: Header
                VStack(alignment: .leading, spacing: 14) {
                    Text("Connect Pact to Screen Time")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("To lock distracting apps until you’ve forged today’s shield, Pact needs your permission.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                // MARK: Benefits card
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.99))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.black)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lock the apps you choose")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                            Text("Pact keeps your most distracting apps locked until you complete today’s Pact.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.99))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.black)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlock with real progress")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                            Text("Apps unlock only after your team approves your proof for the day.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.99))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.black)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("You stay in control")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                            Text("You can change which apps are locked or turn Pact off anytime in Settings.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.97, blue: 0.99))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                // MARK: Primary + secondary actions
                VStack(spacing: 14) {
                    Button(action: requestFamilyControlsAuthorization) {
                        Text("Connect with Screen Time")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(Color.black)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkipTapped) {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)

                    Text("Strongly recommended so Pact can actually lock your apps.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.light)
    }

    private func requestFamilyControlsAuthorization() {
        let center = AuthorizationCenter.shared
        Task {
            do {
                try await center.requestAuthorization(for: .individual)
            } catch {
                print("Authorization failed: \(error)")
            }
            await MainActor.run {
                onConnectTapped()
            }
        }
    }
}

#Preview {
    OnboardingScreenTimeAccessIntroView(
        onBack: {},
        onConnectTapped: {},
        onSkipTapped: {}
    )
}

