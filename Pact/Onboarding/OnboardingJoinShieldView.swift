//
//  JoinShieldView.swift
//  Pact
//
//  Created by Cursor on 2/25/26.
//

import SwiftUI

struct JoinShieldView: View {
    enum CodeField: Int, CaseIterable {
        case box0, box1, box2, box3, box4, box5
    }

    @State private var code: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: CodeField?

    private var isComplete: Bool {
        code.allSatisfy { $0.count == 1 }
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Invite Code")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)

                    Text("Ask your team admin for the 6-digit code.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(white: 0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Code input boxes
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        codeBox(at: index)
                    }
                }
                .padding(.top, 8)

                Spacer()

                // Primary button
                Button(action: {
                    // Hook up join action here (e.g., API call)
                }) {
                    Text("Join Shield")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(isComplete ? 1.0 : 0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isComplete ? Color.black : Color(white: 0.9))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .box0
            }
        }
    }

    // MARK: - Subviews

    private func codeBox(at index: Int) -> some View {
        let field = CodeField(rawValue: index)

        return TextField("", text: Binding(
            get: { code[index] },
            set: { newValue in
                handleInputChange(newValue, at: index)
            }
        ))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .textInputAutocapitalization(.characters)
        .disableAutocorrection(true)
        .multilineTextAlignment(.center)
        .font(.system(size: 24, weight: .semibold, design: .monospaced))
        .foregroundColor(.black)
        .frame(width: 48, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    focusedField == field ? Color.black : Color.clear,
                    lineWidth: 1.5
                )
        )
        .focused($focusedField, equals: field)
    }

    // MARK: - Input Handling

    private func handleInputChange(_ newValue: String, at index: Int) {
        let previous = code[index]

        // Keep only the last allowed character (0–9 or '-')
        let filtered = newValue
            .filter { $0.isASCII && ($0.isNumber || $0 == "-") }

        if let last = filtered.last {
            code[index] = String(last)
            moveFocusForward(from: index)
        } else {
            code[index] = ""

            // If user cleared a non-empty box, optionally move focus back
            if !previous.isEmpty {
                moveFocusBackward(from: index)
            }
        }
    }

    private func moveFocusForward(from index: Int) {
        guard index < 5, let nextField = CodeField(rawValue: index + 1) else { return }
        focusedField = nextField
    }

    private func moveFocusBackward(from index: Int) {
        guard index > 0, let previousField = CodeField(rawValue: index - 1) else { return }
        focusedField = previousField
    }
}

#Preview {
    JoinShieldView()
}

