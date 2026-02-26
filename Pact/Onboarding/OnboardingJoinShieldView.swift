//
//  JoinShieldView.swift
//  Pact
//
//  Created by Cursor on 2/25/26.
//

import SwiftUI

struct JoinShieldView: View {
    @State private var code: String = ""
    @FocusState private var isFieldFocused: Bool

    private var isComplete: Bool {
        code.count == 6
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
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
                Button(action: {
                    // Hook up join action here (e.g., API call)
                }) {
                    Text("Join Shield")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isComplete ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isComplete ? Color.black : Color(white: 0.9))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
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
    JoinShieldView()
}

