//
//  OnboardingFlowView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Flow Steps

private enum OnboardingStep {
    case gender, screenTime
}

// MARK: - Flow Coordinator

struct OnboardingFlowView: View {
    var onFinished: () -> Void

    @State private var step: OnboardingStep = .gender
    @State private var selectedGender: GenderOption?

    var body: some View {
        ZStack {
            switch step {
            case .gender:
                OnboardingGenderView(
                    onContinue: { gender in
                        selectedGender = gender
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
                            step = .gender
                        }
                    },
                    onContinue: { _ in
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
