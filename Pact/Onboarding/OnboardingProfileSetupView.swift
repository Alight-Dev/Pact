//
//  OnboardingProfileSetupView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Avatar Data

private struct AvatarOption: Identifiable {
    let id: Int
    let emoji: String
    let bgColor: Color
}

private let avatarOptions: [AvatarOption] = [
    .init(id: 0, emoji: "🦁", bgColor: Color(red: 1.00, green: 0.88, blue: 0.65)),
    .init(id: 1, emoji: "🐯", bgColor: Color(red: 1.00, green: 0.78, blue: 0.55)),
    .init(id: 2, emoji: "🦊", bgColor: Color(red: 1.00, green: 0.72, blue: 0.45)),
    .init(id: 3, emoji: "🐺", bgColor: Color(red: 0.82, green: 0.86, blue: 0.95)),
    .init(id: 4, emoji: "🦅", bgColor: Color(red: 0.65, green: 0.82, blue: 1.00)),
    .init(id: 5, emoji: "🦋", bgColor: Color(red: 0.88, green: 0.78, blue: 1.00)),
    .init(id: 6, emoji: "🔥", bgColor: Color(red: 1.00, green: 0.65, blue: 0.55)),
    .init(id: 7, emoji: "⚡", bgColor: Color(red: 1.00, green: 0.95, blue: 0.55)),
    .init(id: 8, emoji: "🌊", bgColor: Color(red: 0.55, green: 0.87, blue: 1.00)),
]

// MARK: - Main View

struct OnboardingProfileSetupView: View {
    var firstName: String = "Ethan"
    var onBack: () -> Void
    var onContinue: (String, Int) -> Void   // (nickname, avatarID)

    @State private var nickname: String = ""
    @State private var selectedAvatarID: Int? = nil
    @FocusState private var nicknameFieldFocused: Bool

    private let totalSteps = 7
    private let currentStep = 6

    private var continueEnabled: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty && selectedAvatarID != nil
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

                // MARK: Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome to Pact,")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(Color(white: 0.55))

                            Text(firstName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                        // MARK: Nickname section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Nickname")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.black)

                            Text("This is how teammates will see you.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                        // Text field with inline dice button
                        ZStack(alignment: .trailing) {
                            TextField("", text: $nickname)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.black)
                                .tint(.black)
                                .padding(.leading, 16)
                                .padding(.trailing, 56)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(white: 0.94))
                                )
                                .focused($nicknameFieldFocused)

                            Button(action: randomizeNickname) {
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color(white: 0.45))
                                    .frame(width: 44, height: 44)
                            }
                            .padding(.trailing, 6)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

                        // MARK: Avatar section
                        Text("Choose Your Avatar")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 3),
                            spacing: 20
                        ) {
                            ForEach(avatarOptions) { avatar in
                                AvatarCell(
                                    avatar: avatar,
                                    isSelected: selectedAvatarID == avatar.id
                                ) {
                                    selectedAvatarID = avatar.id
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        // Bottom spacer to clear the fixed Continue button
                        Spacer(minLength: 120)
                    }
                }
            }

            // MARK: Continue button (fixed at bottom)
            Button {
                onContinue(
                    nickname.trimmingCharacters(in: .whitespaces),
                    selectedAvatarID!
                )
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
        .onTapGesture { nicknameFieldFocused = false }
        .preferredColorScheme(.light)
        .onAppear { randomizeNickname() }
    }

    // MARK: - Nickname Generator (Xbox gamertag style)

    private func randomizeNickname() {
        let adjectives = [
            "Swift", "Bold", "Epic", "Fierce", "Brave", "Rapid", "Iron",
            "Stealth", "Hyper", "Dark", "Neon", "Cosmic", "Wild", "Storm",
            "Apex", "Turbo", "Shadow", "Ultra", "Venom", "Blaze"
        ]
        let nouns = [
            "Eagle", "Tiger", "Wolf", "Lion", "Falcon", "Shark", "Hawk",
            "Phoenix", "Cobra", "Panther", "Viper", "Fox", "Bear", "Raven",
            "Titan", "Ghost", "Drift", "Frost", "Nova", "Blaze"
        ]
        let adj  = adjectives.randomElement()!
        let noun = nouns.randomElement()!
        nickname = "\(adj)\(noun)\(Int.random(in: 10...999))"
    }
}

// MARK: - Avatar Cell

private struct AvatarCell: View {
    let avatar: AvatarOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(avatar.bgColor)
                    .frame(width: 90, height: 90)

                Text(avatar.emoji)
                    .font(.system(size: 44))
            }
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.black : Color.clear, lineWidth: 3)
            )
            .shadow(
                color: isSelected ? Color.black.opacity(0.15) : .clear,
                radius: 8, x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(avatar.emoji)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Previews

#Preview("No selection") {
    OnboardingProfileSetupView(onBack: {}, onContinue: { _, _ in })
}

#Preview("All filled") {
    OnboardingProfileSetupView(
        firstName: "Ethan",
        onBack: {},
        onContinue: { _, _ in }
    )
}
