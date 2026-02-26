//
//  OnboardingScreenTimeView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Data Model

enum ScreenTimeOption: String, CaseIterable, Identifiable {
    case underOne    = "Under 1 hour"
    case oneToThree  = "1–3 hours"
    case threeToFour = "3–4 hours"
    case fourToFive  = "4–5 hours"
    case fiveToSeven = "5–7 hours"
    case moreThanSeven = "More than 7 hours"

    var id: String { rawValue }
}

// MARK: - Main View

struct OnboardingScreenTimeView: View {
    var onBack: () -> Void
    var onContinue: (ScreenTimeOption) -> Void

    @State private var selectedOption: ScreenTimeOption?

    init(
        initialSelection: ScreenTimeOption? = nil,
        onBack: @escaping () -> Void,
        onContinue: @escaping (ScreenTimeOption) -> Void
    ) {
        _selectedOption = State(initialValue: initialSelection)
        self.onBack = onBack
        self.onContinue = onContinue
    }

    private let totalSteps = 7
    private let currentStep = 2

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

                // MARK: Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("What is your daily average Screen Time?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("On your phone only. Your best guess is ok.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                // MARK: Option buttons
                VStack(spacing: 12) {
                    ForEach(ScreenTimeOption.allCases) { option in
                        SelectablePillButton(
                            title: option.rawValue,
                            isSelected: selectedOption == option,
                            verticalPadding: 16
                        ) {
                            selectedOption = option
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // MARK: Continue button
                Button {
                    if let option = selectedOption {
                        onContinue(option)
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedOption != nil ? .white : Color.black.opacity(0.30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    selectedOption != nil
                                        ? Color.black
                                        : Color(red: 0.88, green: 0.88, blue: 0.90)
                                )
                        )
                }
                .disabled(selectedOption == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .animation(.easeInOut(duration: 0.2), value: selectedOption)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Previews

#Preview("No selection") {
    OnboardingScreenTimeView(
        onBack: {},
        onContinue: { option in
            print("Continuing with \(option.rawValue)")
        }
    )
}

#Preview("1–3 hours selected") {
    OnboardingScreenTimeView(
        initialSelection: .oneToThree,
        onBack: {},
        onContinue: { _ in }
    )
}
