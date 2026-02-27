//
//  OnboardingTeamNameView.swift
//  Pact
//

import SwiftUI

struct OnboardingTeamNameView: View {
    var onBack: () -> Void
    var onContinue: (String) -> Void

    @State private var teamName: String = ""
    @FocusState private var isFieldFocused: Bool

    private var trimmedName: String {
        teamName.trimmingCharacters(in: .whitespaces)
    }

    private var continueEnabled: Bool {
        !trimmedName.isEmpty
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

                    OnboardingProgressBar(totalSteps: 2, currentStep: 1)
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name Your Shield")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)

                            Text("Choose a name your team will rally behind.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 40)

                        // MARK: Text field
                        TextField("e.g. Morning Forge Alliance", text: $teamName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.black)
                            .tint(.black)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(white: 0.94))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                isFieldFocused ? Color.black : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                            .focused($isFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit {
                                if continueEnabled { onContinue(trimmedName) }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        Spacer(minLength: 160)
                    }
                }
            }

            // MARK: Continue CTA
            Button {
                onContinue(trimmedName)
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
            .animation(.easeInOut(duration: 0.2), value: continueEnabled)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onTapGesture { isFieldFocused = false }
        .preferredColorScheme(.light)
    }
}

// MARK: - Preview

#Preview {
    OnboardingTeamNameView(
        onBack: {},
        onContinue: { name in print("Team name: \(name)") }
    )
}
