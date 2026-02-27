//
//  JoinShieldView.swift
//  Pact
//
//  Created by Cursor on 2/25/26.
//

import SwiftUI

struct JoinShieldView: View {
    var onBack: () -> Void
    var onJoined: () -> Void

    @EnvironmentObject var firestoreService: FirestoreService

    @State private var code: String = ""
    @FocusState private var isFieldFocused: Bool
    @State private var isJoining = false
    @State private var joinError: String?

    private var isComplete: Bool {
        code.count == 6
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top back button
                HStack(spacing: 8) {
                    Button(action: {
                        onBack()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .center, spacing: 8) {
                        Text("Enter Invite Code")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.black)

                        Text("Ask your team admin for the 6-digit code.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Code input boxes (driven by a single hidden TextField)
                    ZStack {
                        // Invisible text field capturing all input
                        TextField("", text: Binding(
                            get: { code },
                            set: { newValue in
                                handleCodeChange(newValue)
                            }
                        ))
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .foregroundColor(.clear)
                        .accentColor(.clear)
                        .focused($isFieldFocused)
                        .frame(width: 0, height: 0)
                        .opacity(0.05)

                        // Visual boxes
                        HStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { index in
                                codeBox(at: index)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFieldFocused = true
                }

                // Primary button
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Button {
                            isJoining = true
                            joinError = nil
                            Task {
                                do {
                                    _ = try await firestoreService.joinTeam(inviteCode: code)
                                    onJoined()
                                } catch {
                                    joinError = error.localizedDescription
                                }
                                isJoining = false
                            }
                        } label: {
                            Group {
                                if isJoining {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(isComplete ? .white : .black)
                                } else {
                                    Text("Join Shield")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(isComplete ? .white : .black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isComplete && !isJoining ? Color.black : Color(white: 0.9))
                            )
                        }
                        .frame(maxWidth: 320)
                        .buttonStyle(.plain)
                        .disabled(!isComplete || isJoining)
                        Spacer()
                    }

                    if let error = joinError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 32)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 0)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.async {
                isFieldFocused = true
            }
        }
    }

    // MARK: - Subviews

    private func codeBox(at index: Int) -> some View {
        let characters = Array(code)
        let character: String = index < characters.count ? String(characters[index]) : ""
        let isActive = isFieldFocused && index == min(code.count, 5)

        return Text(character)
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.black : Color.clear, lineWidth: 1.5)
            )
    }

    // MARK: - Input Handling

    private func handleCodeChange(_ newValue: String) {
        // Allow only numeric digits 0–9
        let filtered = newValue.filter { $0.isASCII && $0.isNumber }

        // Enforce max length 6
        let limited = String(filtered.prefix(6))

        // Detect backspace (shorter than current) and simply assign
        if limited.count <= code.count {
            code = limited
        } else {
            // User added characters; only keep up to 6
            code = limited
        }

        // Dismiss keyboard when complete
        if code.count == 6 {
            isFieldFocused = false
        }
    }
}

#Preview {
    JoinShieldView(onBack: {}, onJoined: {})
        .environmentObject(FirestoreService())
}

