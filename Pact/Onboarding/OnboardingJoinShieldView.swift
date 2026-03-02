//
//  JoinShieldView.swift
//  Pact
//
//  Created by Cursor on 2/25/26.
//

import SwiftUI
import FirebaseFunctions

struct JoinShieldView: View {
    var onBack: () -> Void
    var onJoined: () -> Void
    var initialCode: String = ""

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

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter Invite Code")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)

                            Text("Ask your team admin for the 6-digit code\nto join their Shield.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.55))
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 40)

                        // MARK: Code input
                        ZStack {
                            TextField("", text: Binding(
                                get: { code },
                                set: { handleCodeChange($0) }
                            ))
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .foregroundColor(.clear)
                            .tint(.clear)
                            .focused($isFieldFocused)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .opacity(0.011)
                            .allowsHitTesting(true)

                            codeBoxesView
                                .allowsHitTesting(false)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .contentShape(Rectangle())
                        .onTapGesture { isFieldFocused = true }

                        // MARK: Error
                        if let error = joinError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                        }

                        Spacer(minLength: 160)
                    }
                }
            }

            // MARK: Join CTA
            Button {
                performJoin()
            } label: {
                Group {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(isComplete ? .white : Color.black.opacity(0.30))
                    } else {
                        Text("Join Shield")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isComplete ? .white : Color.black.opacity(0.30))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            isComplete && !isJoining
                                ? Color.black
                                : Color(red: 0.88, green: 0.88, blue: 0.90)
                        )
                )
            }
            .disabled(!isComplete || isJoining)
            .animation(.easeInOut(duration: 0.2), value: isComplete)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onTapGesture { isFieldFocused = false }
        .onAppear {
            if !initialCode.isEmpty && code.isEmpty {
                code = initialCode
            }
            DispatchQueue.main.async { isFieldFocused = true }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Code Boxes

    private var codeBoxesView: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                codeBox(at: index)
            }

            Text("–")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(white: 0.78))
                .frame(width: 14)

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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .transition(.scale.combined(with: .opacity))
            } else if isActive {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 2, height: 22)
                    .opacity(cursorVisible ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isFilled ? Color.white : Color(red: 0.94, green: 0.94, blue: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isActive ? Color.black :
                    isFilled ? Color.black.opacity(0.06) : Color.black.opacity(0.04),
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .shadow(
            color: isFilled ? Color.black.opacity(0.06) : .clear,
            radius: 8, x: 0, y: 3
        )
        .scaleEffect(isActive ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFilled)
    }

    // MARK: - Actions

    private func performJoin() {
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
            } catch let error as NSError {
                if error.domain == FunctionsErrorDomain,
                   let code = FunctionsErrorCode(rawValue: error.code),
                   code == .alreadyExists {
                    joinError = "You're already in a team. Leave your current team first to join another."
                } else {
                    joinError = error.localizedDescription
                }
            }
            isJoining = false
        }
    }

    // MARK: - Input Handling

    private func handleCodeChange(_ newValue: String) {
        let filtered = newValue.filter { $0.isASCII && $0.isNumber }
        let limited = String(filtered.prefix(6))
        code = limited

        if code.count == 6 {
            isFieldFocused = false
        }
    }
}

#Preview {
    JoinShieldView(onBack: {}, onJoined: {})
        .environmentObject(FirestoreService())
}
