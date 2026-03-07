//
//  OnboardingNameConfirmationView.swift
//  Pact
//
//  Shown immediately after Apple/Google sign-in. Pre-fills name from auth
//  and lets the user confirm or edit before it is saved to Firebase Auth (and
//  later to Firestore at end of onboarding).
//

import SwiftUI

struct OnboardingNameConfirmationView: View {
    var initialFirstName: String
    var initialLastName: String
    var onBack: () -> Void
    var onContinue: () async -> Void

    @EnvironmentObject var authManager: AuthManager

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var contentVisible = false
    @State private var isExiting = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName, lastName
    }

    private var fullName: String {
        [firstName.trimmingCharacters(in: .whitespacesAndNewlines),
         lastName.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var continueEnabled: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
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

                    Spacer()

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

                // MARK: Title + fields — positioned high, with enter/exit animation
                VStack(alignment: .leading, spacing: 24) {
                    Text("What's your name?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)

                    VStack(alignment: .leading, spacing: 12) {
                        nameField(
                            placeholder: "First name",
                            text: $firstName,
                            field: .firstName
                        )
                        .submitLabel(.next)

                        nameField(
                            placeholder: "Last name",
                            text: $lastName,
                            field: .lastName
                        )
                        .submitLabel(.done)
                    }

                    Text("Tap a field to edit")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.55))

                    if let msg = errorMessage {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(contentVisible && !isExiting ? 1 : 0)
                .offset(y: contentVisible && !isExiting ? 0 : 20)
                .scaleEffect(isExiting ? 0.96 : 1)

                Spacer()

                // MARK: Continue
                Button {
                    Task {
                        isSaving = true
                        errorMessage = nil
                        do {
                            try await authManager.updateDisplayName(fullName)
                            await MainActor.run {
                                withAnimation(.easeIn(duration: 0.28)) {
                                    isExiting = true
                                }
                            }
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            await onContinue()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isSaving = false
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(continueEnabled ? Color.black : Color.black.opacity(0.4))
                    )
                }
                .disabled(!continueEnabled || isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if firstName.isEmpty && lastName.isEmpty {
                firstName = initialFirstName
                lastName = initialLastName
            }
            withAnimation(.easeOut(duration: 0.4)) {
                contentVisible = true
            }
        }
        .animation(.easeOut(duration: 0.25), value: focusedField)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func nameField(placeholder: String, text: Binding<String>, field: Field) -> some View {
        let isFocused = focusedField == field
        Button {
            focusedField = field
        } label: {
            TextField(placeholder, text: text)
                .textContentType(field == .firstName ? .givenName : .familyName)
                .autocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .font(.system(size: 17))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isFocused ? Color.black : Color.black.opacity(0.08),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .accessibilityHint("Editable. \(placeholder)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("OnboardingNameConfirmationView") {
    OnboardingNameConfirmationView(
        initialFirstName: "Yaw",
        initialLastName: "Jnr",
        onBack: {},
        onContinue: {}
    )
    .environmentObject(AuthManager())
}
