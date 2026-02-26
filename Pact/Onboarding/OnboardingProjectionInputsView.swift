//
//  OnboardingProjectionInputsView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Data Model

enum AppCategoryOption: String, CaseIterable, Identifiable {
    case socialMedia = "Social Media"
    case streaming   = "Streaming"
    case gaming      = "Gaming"
    case messaging   = "Messaging"
    case other       = "Other"

    var id: String { rawValue }
}

// MARK: - Main View

struct OnboardingProjectionInputsView: View {
    var onBack: () -> Void
    var onContinue: (Int, AppCategoryOption) -> Void

    @State private var smartphoneYears: Double = 5
    @State private var selectedCategory: AppCategoryOption?

    private let totalSteps = 7
    private let currentStep = 3

    private var continueEnabled: Bool { selectedCategory != nil }

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
                    Text("What eats most of your time?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("We'll use this to personalize your stats.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                // MARK: Slider section
                VStack(alignment: .leading, spacing: 16) {
                    Text("YEARS WITH A SMARTPHONE")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                        .tracking(0.5)
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        // Current value label
                        Text("\(Int(smartphoneYears)) \(Int(smartphoneYears) == 1 ? "year" : "years")")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Slider with end labels
                        HStack(spacing: 12) {
                            Text("1")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(white: 0.55))

                            Slider(value: $smartphoneYears, in: 1...15, step: 1)
                                .tint(.black)

                            Text("15")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(white: 0.55))
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()

                // MARK: Category section
                VStack(alignment: .leading, spacing: 14) {
                    Text("YOUR BIGGEST TIME SINK")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                        .tracking(0.5)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        ForEach(AppCategoryOption.allCases) { option in
                            SelectablePillButton(
                                title: option.rawValue,
                                isSelected: selectedCategory == option,
                                verticalPadding: 16
                            ) {
                                selectedCategory = option
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // MARK: Continue button
                Button {
                    if let category = selectedCategory {
                        onContinue(Int(smartphoneYears), category)
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(continueEnabled ? .white : Color.black.opacity(0.30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    continueEnabled
                                        ? Color.black
                                        : Color(red: 0.88, green: 0.88, blue: 0.90)
                                )
                        )
                }
                .disabled(!continueEnabled)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .animation(.easeInOut(duration: 0.2), value: continueEnabled)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Previews

#Preview("No selection") {
    OnboardingProjectionInputsView(
        onBack: {},
        onContinue: { years, category in
            print("Years: \(years), Category: \(category.rawValue)")
        }
    )
}

#Preview("Social Media selected") {
    OnboardingProjectionInputsView(
        onBack: {},
        onContinue: { _, _ in }
    )
}
