//
//  OnboardingProjectionView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Projection Engine

struct ScreenTimeProjectionEngine {
    let age: AgeOption
    let screenTime: ScreenTimeOption
    let years: Int
    let categories: Set<AppCategoryOption>

    private var ageNumeric: Int {
        switch age {
        case .underEighteen:  return 17
        case .eighteenTo24:   return 21
        case .twentyFiveTo34: return 30
        case .thirtyFiveTo44: return 40
        case .fortyFiveTo55:  return 50
        case .fiftyFiveTo64:  return 60
        case .overSixtyFour:  return 70
        }
    }

    private var dailyHours: Double {
        switch screenTime {
        case .underOne:      return 0.5
        case .oneToThree:    return 2.0
        case .threeToFour:   return 3.5
        case .fourToFive:    return 4.5
        case .fiveToSeven:   return 6.0
        case .moreThanSeven: return 8.0
        }
    }

    var fiveYearHours: Double    { dailyHours * 365 * 5 }
    var fiveYearMonths: Double   { fiveYearHours / (24 * 30) }
    var fiveYearDays: Double     { fiveYearHours / 24 }

    var lifetimeYearsRemaining: Int { max(0, 80 - ageNumeric) }
    var lifetimeHours: Double       { dailyHours * 365 * Double(lifetimeYearsRemaining) }
    var lifetimePhoneYears: Double  { lifetimeHours / 8760 }

    var reclaimDays5yr: Double { (dailyHours / 2) * 365 * 5 / 24 }

    var impactHeadline: String {
        let months = Int(fiveYearMonths.rounded())
        return "\(months) month\(months == 1 ? "" : "s") on your phone"
    }

    var impactBody: String {
        "Over the next 5 years, at your current pace."
    }

    var reclaimHeadline: String {
        let days = Int(reclaimDays5yr.rounded())
        return "\(days) full day\(days == 1 ? "" : "s") back"
    }

    var reclaimBody: String {
        "If you cut your screen time in half over the next 5 years."
    }
}

// MARK: - Main View

struct OnboardingProjectionView: View {
    let age: AgeOption
    let screenTime: ScreenTimeOption
    let years: Int
    let categories: Set<AppCategoryOption>
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var displayedMonths: Double = 0
    @State private var displayedReclaimDays: Double = 0

    private let totalSteps = 8
    private let currentStep = 4

    private var engine: ScreenTimeProjectionEngine {
        ScreenTimeProjectionEngine(
            age: age,
            screenTime: screenTime,
            years: years,
            categories: categories
        )
    }

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
                    Text("Let's look at the future.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Based on your current habits.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                // MARK: Cards
                VStack(spacing: 16) {

                    // Impact card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("In the next 5 years")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.bottom, 10)

                        Text(formatCount(displayedMonths))
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.black)
                            .monospacedDigit()

                        Text("months on your phone")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.top, 4)

                        Divider()
                            .padding(.vertical, 14)

                        Text(engine.impactBody)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.55))
                            .lineSpacing(3)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(white: 0.96))
                    )

                    // Reclaim card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("If you cut your screen time in half")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.bottom, 10)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(formatCount(displayedReclaimDays))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)
                                .monospacedDigit()

                            Text("days")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)
                        }

                        Text(engine.reclaimBody)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.top, 10)
                            .lineSpacing(3)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.black, lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // MARK: Continue button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(Color.black))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.light)
        .task {
            let targetMonths = engine.fiveYearMonths
            let targetDays   = engine.reclaimDays5yr
            let totalSteps   = 50
            for step in 1...totalSteps {
                displayedMonths      = targetMonths * Double(step) / Double(totalSteps)
                displayedReclaimDays = targetDays   * Double(step) / Double(totalSteps)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            displayedMonths      = targetMonths
            displayedReclaimDays = targetDays
        }
    }

    // MARK: - Helpers

    private func formatCount(_ value: Double) -> String {
        Int(value).formatted()
    }
}

// MARK: - Previews

#Preview {
    OnboardingProjectionView(
        age: .twentyFiveTo34,
        screenTime: .threeToFour,
        years: 8,
        categories: [.socialMedia],
        onBack: {},
        onContinue: {}
    )
}
