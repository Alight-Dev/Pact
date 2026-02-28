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
    @State private var cursorVisible = true

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

                    ZStack {
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
                        .tint(.clear)
                        .focused($isFieldFocused)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .opacity(0.011)
                        .allowsHitTesting(true)

                        codeBoxesView
                            .allowsHitTesting(false)
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
                                    let joinResult = try await firestoreService.joinTeam(inviteCode: code)
                                    let membership = try await firestoreService.loadActiveMembership()
                                    await MainActor.run {
                                        if let membership {
                                            firestoreService.startTeamSession(
                                                teamId: membership.teamId,
                                                teamName: membership.teamName,
                                                adminTimezone: membership.adminTimezone
                                            )
                                        } else {
                                            firestoreService.startTeamSession(
                                                teamId: joinResult.teamId,
                                                teamName: joinResult.teamName,
                                                adminTimezone: TimeZone.current.identifier
                                            )
                                        }
                                        onJoined()
                                    }
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

    private var codeBoxesView: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                codeBox(at: index)
            }

            Text("–")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(white: 0.75))
                .frame(width: 12)

            ForEach(3..<6, id: \.self) { index in
                codeBox(at: index)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                cursorVisible.toggle()
            }
        }
    }

    private func codeBox(at index: Int) -> some View {
        let characters = Array(code)
        let isFilled = index < characters.count
        let character: String = isFilled ? String(characters[index]) : ""
        let isActive = isFieldFocused && index == min(code.count, 5)

        return ZStack {
            if isFilled {
                Text(character)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .transition(.scale.combined(with: .opacity))
            } else if isActive {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 2, height: 24)
                    .opacity(cursorVisible ? 1 : 0)
            }
        }
        .frame(width: 50, height: 62)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isFilled ? Color.white : Color(white: 0.965))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isActive ? Color.black :
                    isFilled ? Color(white: 0.88) : Color(white: 0.92),
                    lineWidth: isActive ? 2 : 1
                )
        )
        .shadow(
            color: isActive ? Color.black.opacity(0.08) :
                   isFilled ? Color.black.opacity(0.04) : .clear,
            radius: isActive ? 8 : 4,
            x: 0,
            y: isActive ? 3 : 2
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFilled)
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

