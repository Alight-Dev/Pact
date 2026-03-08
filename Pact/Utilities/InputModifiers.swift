//
//  InputModifiers.swift
//  Pact
//
//  SwiftUI ViewModifiers for real-time character filtering and length limiting.
//

import SwiftUI

// MARK: - ValidatedField ViewModifier

/// Strips characters not allowed by `rule` and enforces its maximum length
/// as the user types. Works on any `TextField` or `TextEditor`.
///
/// Usage:
/// ```swift
/// TextField("Team name", text: $teamName)
///     .validated(by: .teamName, text: $teamName)
/// ```
private struct ValidatedField: ViewModifier {
    let rule: InputValidator.Rule
    @Binding var text: String

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, newValue in
                let sanitized = InputValidator.filter(newValue, rule: rule)
                // Only write back if something actually changed to avoid
                // triggering an infinite onChange loop.
                if sanitized != newValue {
                    text = sanitized
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches real-time character filtering for `rule` to this text field.
    /// Illegal characters are stripped and the string is truncated to the
    /// rule's maximum length on every keystroke.
    func validated(by rule: InputValidator.Rule, text: Binding<String>) -> some View {
        modifier(ValidatedField(rule: rule, text: text))
    }
}
