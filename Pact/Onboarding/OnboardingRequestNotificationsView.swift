//
//  OnboardingRequestNotificationsView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/26/26.
//

import SwiftUI
import UserNotifications

struct OnboardingRequestNotificationsView: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    private let totalSteps = 8
    private let currentStep = 5

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Navigation row
                HStack(alignment: .center) {
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

                // MARK: Phone illustration with notification card
                ZStack(alignment: .top) {
                    // Phone body — gradient from grey at top to white at bottom
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.91), Color.white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 210, height: 280)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color(white: 1), lineWidth: 0.5)
                        )

                    // Dynamic island pill
                    Capsule()
                        .fill(Color(white: 0.55))
                        .frame(width: 72, height: 20)
                        .padding(.top, 14)

                    // Notification card — wider than phone, extends outside bounds
                    NotificationPreviewCard()
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 52)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)


                // MARK: Headline
                Text("Stay in the loop of your\nfriends achievements.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                // Reserve space for bottom buttons so headline is never covered
                Spacer(minLength: 130)
            }

            // MARK: Bottom buttons (pinned to bottom)
            VStack(spacing: 0) {
                // Allow notifications
                Button {
                    Task {
                        try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .badge, .sound])
                        await MainActor.run { onContinue() }
                    }
                } label: {
                    Text("Allow notifications")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(Color.black))
                }

                // Not now
                Button(action: onContinue) {
                    Text("Not now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Notification Preview Card

private struct NotificationPreviewCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.86))
                .frame(width: 52, height: 52)
                .overlay(
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                )

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text("James finished an activity!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text("Review their submission")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("Just now")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.60))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.09), radius: 16, x: 0, y: 6)
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingRequestNotificationsView(onBack: {}, onContinue: {})
}
