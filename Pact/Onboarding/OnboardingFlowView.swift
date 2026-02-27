//
//  OnboardingFlowView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Flow Steps

private enum OnboardingStep {
    case gender, age, screenTime, projectionInputs, projectionLoading, projectionResult, requestNotifications, signup, profileSetup
}

// MARK: - Flow Coordinator

struct OnboardingFlowView: View {
    var onFinished: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var step: OnboardingStep = .gender
    @State private var isGoingForward = true
    @State private var selectedGender: GenderOption?
    @State private var selectedAge: AgeOption?
    @State private var selectedScreenTime: ScreenTimeOption?
    @State private var selectedSmartphoneYears: Int = 5
    @State private var selectedCategories: Set<AppCategoryOption> = []
    @State private var profileNickname: String = ""
    @State private var profileAvatarID: Int = 0
    @State private var profileAvatarAssetName: String = ""

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading),
            removal:   .move(edge: isGoingForward ? .leading  : .trailing)
        )
    }

    var body: some View {
        ZStack {
            switch step {
            case .gender:
                OnboardingGenderView(
                    onContinue: { gender in
                        selectedGender = gender
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .age
                        }
                    }
                )
                .transition(slideTransition)

            case .age:
                OnboardingAgeView(
                    initialSelection: selectedAge,
                    onBack: {
                        isGoingForward = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .gender
                        }
                    },
                    onContinue: { age in
                        selectedAge = age
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .screenTime
                        }
                    }
                )
                .transition(slideTransition)

            case .screenTime:
                OnboardingScreenTimeView(
                    onBack: {
                        isGoingForward = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .age
                        }
                    },
                    onContinue: { screenTime in
                        selectedScreenTime = screenTime
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionInputs
                        }
                    }
                )
                .transition(slideTransition)

            case .projectionInputs:
                OnboardingProjectionInputsView(
                    onBack: {
                        isGoingForward = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .screenTime
                        }
                    },
                    onContinue: { years, categories in
                        selectedSmartphoneYears = years
                        selectedCategories = categories
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionLoading
                        }
                    }
                )
                .transition(slideTransition)

            case .projectionLoading:
                OnboardingLoadingView(
                    onFinished: {
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionResult
                        }
                    }
                )
                .transition(slideTransition)

            case .projectionResult:
                OnboardingProjectionView(
                    age: selectedAge!,
                    screenTime: selectedScreenTime!,
                    years: selectedSmartphoneYears,
                    categories: selectedCategories,
                    onBack: {
                        isGoingForward = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionInputs   // skip loading on back
                        }
                    },
                    onContinue: {
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .requestNotifications
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .requestNotifications:
                OnboardingRequestNotificationsView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .projectionResult
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .signup
                        }
                    }
                )
                .transition(slideTransition)

            case .signup:
                OnboardingSignupView(
                    onBack: {
                        isGoingForward = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .requestNotifications
                        }
                    },
                    onContinue: {
                        isGoingForward = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .profileSetup
                        }
                    }
                )
                .transition(slideTransition)

            case .profileSetup:
                OnboardingProfileSetupView(
                    firstName: authManager.currentUser?.displayName?.components(separatedBy: " ").first,
                    onBack: {
                        isGoingForward = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .signup
                        }
                    },
                    onContinue: { nickname, avatarID, assetName in
                        profileNickname = nickname
                        profileAvatarID = avatarID
                        profileAvatarAssetName = assetName
                        // Save profile to Firestore (best-effort — onboarding still proceeds on error)
                        if let user = authManager.currentUser {
                            Task {
                                try? await firestoreService.saveUserProfile(
                                    uid: user.uid,
                                    displayName: user.displayName ?? "",
                                    email: user.email,
                                    isAnonymous: user.isAnonymous,
                                    nickname: nickname,
                                    avatarID: avatarID,
                                    avatarAssetName: assetName,
                                    gender: selectedGender?.rawValue ?? "",
                                    ageRange: selectedAge?.rawValue ?? "",
                                    dailyScreenTime: selectedScreenTime?.rawValue ?? "",
                                    smartphoneYears: selectedSmartphoneYears,
                                    appCategories: selectedCategories.map(\.rawValue)
                                )
                            }
                        }
                        onFinished()
                    }
                )
                .transition(slideTransition)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView(onFinished: {
        print("Onboarding finished")
    })
    .environmentObject(AuthManager())
    .environmentObject(FirestoreService())
}
