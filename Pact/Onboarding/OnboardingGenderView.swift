//
//  OnboardingGenderView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Data Model

enum GenderOption: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Main View

struct OnboardingGenderView: View {
    var onContinue: (GenderOption) -> Void

    @State private var selectedGender: GenderOption?

    init(
        initialSelection: GenderOption? = nil,
        onContinue: @escaping (GenderOption) -> Void
    ) {
        _selectedGender = State(initialValue: initialSelection)
        self.onContinue = onContinue
    }

    private let totalSteps = 8
    private let currentStep = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Navigation row
                HStack(alignment: .center) {
                    // Placeholder to balance layout (no back button on first screen)
                    Color.clear
                        .frame(width: 40, height: 40)

                    // Thin step progress bar
                    OnboardingProgressBar(totalSteps: totalSteps, currentStep: currentStep)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)

                    // Language selector pill
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
                    Text("Choose your Gender")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This will be used to calibrate your custom plan.")
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
                    ForEach(GenderOption.allCases) { option in
                        SelectablePillButton(
                            title: option.rawValue,
                            isSelected: selectedGender == option
                        ) {
                            selectedGender = option
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // MARK: Continue button
                Button {
                    if let gender = selectedGender {
                        onContinue(gender)
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedGender != nil ? .white : Color.black.opacity(0.30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    selectedGender != nil
                                        ? Color.black
                                        : Color(red: 0.88, green: 0.88, blue: 0.90)
                                )
                        )
                }
                .disabled(selectedGender == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .animation(.easeInOut(duration: 0.2), value: selectedGender)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Previews

#Preview("No selection") {
    OnboardingGenderView(
        onContinue: { gender in
            print("Continuing with \(gender.rawValue)")
        }
    )
}

#Preview("Female selected") {
    OnboardingGenderView(
        initialSelection: .female,
        onContinue: { _ in }
    )
}
