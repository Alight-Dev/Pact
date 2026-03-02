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
    let assetName: String   // matches name in Assets.xcassets
}

// 50 DiceBear avataaars — bundled as PNG assets (no runtime network calls).
// Order is shuffled per session; the main screen shows the first 16.
private let allAvatarOptions: [AvatarOption] = [
    // Batch 1 (original 20)
    "felix", "mia", "sam", "alex", "jordan",
    "riley", "avery", "quinn", "morgan", "taylor",
    "casey", "blake", "drew", "sage", "skyler",
    "river", "storm", "nova", "zara", "kai",
    // Batch 2 (additional 30)
    "chris", "dana", "eden", "finn", "gray",
    "hana", "ivan", "jade", "kira", "liam",
    "maya", "nate", "opal", "pine", "remy",
    "sara", "tara", "umar", "vera", "wren",
    "xena", "yuki", "zeus", "aria", "beau",
    "cleo", "dex", "ella", "fawn", "glen"
].enumerated().map { index, name in
    AvatarOption(id: index, assetName: "avatar_\(name)")
}

// MARK: - Main View

struct OnboardingProfileSetupView: View {
    var firstName: String? = nil
    var onBack: () -> Void
    var onContinue: (String, Int, String) -> Void   // (nickname, avatarID, avatarAssetName)

    @State private var nickname: String = ""
    @State private var selectedAvatarID: Int? = nil
    @State private var shuffledAvatars: [AvatarOption] = []
    @State private var showAvatarPicker = false
    @State private var showMoreVisible = false

    @FocusState private var nicknameFieldFocused: Bool

    private let totalSteps = 8
    private let currentStep = 7

    private var continueEnabled: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty && selectedAvatarID != nil
    }

    // First 12 from the shuffled pool — shown in the main 4×3 grid
    private var previewAvatars: [AvatarOption] {
        Array(shuffledAvatars.prefix(12))
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
                            if let name = firstName {
                                Text("Welcome, \(name)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.black)
                            } else {
                                Text("Welcome to Pact!")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.black)
                            }
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

                        // Text field — letters and digits only (no spaces, no emoji)
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
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: nickname) { _, new in
                                    let filtered = new.filter { $0.isLetter || $0.isNumber }
                                    if filtered != new { nickname = filtered }
                                }

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

                        // 4×4 preview grid — first 16 from the shuffled pool
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                            spacing: 10
                        ) {
                            ForEach(previewAvatars) { avatar in
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

                        // Bottom spacer — taller now to clear both fixed buttons
                        Spacer(minLength: 160)
                    }
                }
            }

            // MARK: Fixed bottom area — Show More (springs up) + Continue
            VStack(spacing: 12) {

                // "Show more avatars" — hidden initially, springs up from behind Continue
                Button {
                    nicknameFieldFocused = false
                    showAvatarPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Show more avatars")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color(white: 0.30))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.96))
                            .overlay(
                                Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .opacity(showMoreVisible ? 1 : 0)
                .offset(y: showMoreVisible ? 0 : 28)

                // Continue — primary CTA, always at the very bottom
                Button {
                    let assetName = shuffledAvatars.first { $0.id == selectedAvatarID! }?.assetName ?? "avatar_felix"
                    onContinue(
                        nickname.trimmingCharacters(in: .whitespaces),
                        selectedAvatarID!,
                        assetName
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
                .animation(.easeInOut(duration: 0.2), value: continueEnabled)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onTapGesture { nicknameFieldFocused = false }
        .preferredColorScheme(.light)
        .onAppear {
            if let first = firstName, !first.isEmpty {
                nickname = first
            } else {
                randomizeNickname()
            }
            shuffledAvatars = allAvatarOptions.shuffled()
            // "Show more" springs up from behind Continue after a brief beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    showMoreVisible = true
                }
            }
        }
        // When the sheet selection changes to an avatar not already in the preview,
        // move it to position 0 so the user can see and confirm it in the main grid.
        .onChange(of: selectedAvatarID) { _, newID in
            guard showAvatarPicker, let id = newID else { return }
            bringAvatarToFront(id: id)
        }
        // MARK: Avatar picker sheet
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet(
                avatars: shuffledAvatars,
                selectedAvatarID: $selectedAvatarID,
                onDismiss: { showAvatarPicker = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Avatar surfacing (sheet → main grid)

    /// If the chosen avatar is outside the 12-item preview, move it to position 0
    /// so the user sees it highlighted in the main grid the moment the sheet closes.
    private func bringAvatarToFront(id: Int) {
        guard
            !previewAvatars.contains(where: { $0.id == id }),
            let idx = shuffledAvatars.firstIndex(where: { $0.id == id })
        else { return }
        let avatar = shuffledAvatars.remove(at: idx)
        shuffledAvatars.insert(avatar, at: 0)
    }

    // MARK: - Nickname Generator (Xbox gamertag style — no spaces, no emoji)

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

// MARK: - Avatar Picker Sheet

private struct AvatarPickerSheet: View {
    let avatars: [AvatarOption]
    @Binding var selectedAvatarID: Int?
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Sheet header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All Avatars")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                    Text("\(avatars.count) options")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.55))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.40))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(white: 0.92)))
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 24)

            // MARK: Full scrollable avatar grid
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                    spacing: 12
                ) {
                    ForEach(avatars) { avatar in
                        AvatarCell(
                            avatar: avatar,
                            isSelected: selectedAvatarID == avatar.id
                        ) {
                            selectedAvatarID = avatar.id
                            // Brief delay so the selection ring animates before dismissal
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                onDismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.white)
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
                    .fill(Color(white: 0.94))
                Image(avatar.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(Circle())
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
        .accessibilityLabel(avatar.assetName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Previews

#Preview("No selection") {
    OnboardingProfileSetupView(onBack: {}, onContinue: { _, _, _ in })
}

#Preview("With name") {
    OnboardingProfileSetupView(
        firstName: "Alex",
        onBack: {},
        onContinue: { _, _, _ in }
    )
}
