//
//  OnboardingFlowView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Flow Steps

private enum OnboardingStep {
    case gender, age, screenTime, projectionInputs, projectionResult, signup, profileSetup
}

// MARK: - Flow Coordinator

struct OnboardingFlowView: View {
    var onFinished: () -> Void

    @State private var step: OnboardingStep = .gender
    @State private var selectedGender: GenderOption?
    @State private var selectedAge: AgeOption?
    @State private var selectedScreenTime: ScreenTimeOption?
    @State private var selectedSmartphoneYears: Int = 5
    @State private var selectedCategory: AppCategoryOption?
    @State private var profileNickname: String = ""
    @State private var profileAvatarID: Int = 0

    var body: some View {
        ZStack {
            switch step {
            case .gender:
                OnboardingGenderView(
                    onContinue: { gender in
                        selectedGender = gender
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .age
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .age:
                OnboardingAgeView(
                    initialSelection: selectedAge,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .gender
                        }
                    },
                    onContinue: { age in
                        selectedAge = age
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .screenTime
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .screenTime:
                OnboardingScreenTimeView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .age
                        }
                    },
                    onContinue: { screenTime in
                        selectedScreenTime = screenTime
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionInputs
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .projectionInputs:
                OnboardingProjectionInputsView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .screenTime
                        }
                    },
                    onContinue: { years, category in
                        selectedSmartphoneYears = years
                        selectedCategory = category
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionResult
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .projectionResult:
                OnboardingProjectionView(
                    age: selectedAge!,
                    screenTime: selectedScreenTime!,
                    years: selectedSmartphoneYears,
                    category: selectedCategory!,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionInputs
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .signup
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .signup:
                OnboardingSignupView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionResult
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .profileSetup
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .profileSetup:
                OnboardingProfileSetupView(
                    firstName: "Ethan",
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .signup
                        }
                    },
                    onContinue: { nickname, avatarID in
                        profileNickname = nickname
                        profileAvatarID = avatarID
                        onFinished()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView(onFinished: {
        print("Onboarding finished")
    })
}
