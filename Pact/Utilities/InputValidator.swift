//
//  InputValidator.swift
//  Pact
//
//  Centralised input validation and sanitization.
//  All regex patterns are compiled once at startup (static let) to avoid
//  per-keystroke recompilation overhead.
//

import Foundation

// MARK: - InputValidator

/// Pure, stateless validation and sanitization namespace.
/// Use `validate(_:rule:)` for guard checks and `filter(_:rule:)` to strip
/// illegal characters in real-time as the user types.
enum InputValidator {

    // MARK: - Rules

    /// The set of named validation rules used across the app.
    enum Rule {
        /// Alphanumeric only, 2–20 characters. Used for gamertag nicknames.
        case nickname
        /// Alphanumeric, spaces, apostrophes, hyphens, 2–30 characters. Used for team names.
        case teamName
        /// Unicode letters, spaces, hyphens, 1–50 characters. Used for display names.
        case displayName
        /// Printable ASCII (0x20–0x7E), 1–20 characters. Used for activity names.
        case activityName
        /// Simplified RFC-5322 email format.
        case email
        /// Exactly 6 decimal digits. Used for team invite codes.
        case inviteCode
    }

    // MARK: - Compiled Regex (computed once)

    private static let patterns: [Rule: String] = [
        .nickname:     #"^[a-zA-Z0-9]{2,20}$"#,
        .teamName:     #"^[a-zA-Z0-9 '\-]{2,30}$"#,
        .displayName:  #"^[\p{L} \-]{1,50}$"#,
        .activityName: #"^[\x20-\x7E]{1,20}$"#,
        .email:        #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#,
        .inviteCode:   #"^[0-9]{6}$"#,
    ]

    /// Character sets allowed by each rule (used for O(1) per-char filtering).
    private static let allowedCharsets: [Rule: CharacterSet] = [
        .nickname:     .alphanumerics,
        .teamName:     CharacterSet.alphanumerics.union(.init(charactersIn: " '-")),
        .displayName:  CharacterSet.letters.union(.init(charactersIn: " -")),
        .activityName: CharacterSet(charactersIn: Unicode.Scalar(0x20)! ... Unicode.Scalar(0x7E)!),
        .inviteCode:   .decimalDigits,
        // Email is not filtered character-by-character (too complex); validate only.
        .email:        CharacterSet.alphanumerics.union(.init(charactersIn: "@._+-")),
    ]

    /// Maximum lengths enforced during filtering (mirrors regex upper bounds).
    private static let maxLengths: [Rule: Int] = [
        .nickname:     20,
        .teamName:     30,
        .displayName:  50,
        .activityName: 20,
        .email:        254,  // RFC-5321 maximum
        .inviteCode:   6,
    ]

    // MARK: - Validate

    /// Returns `true` when `value` fully satisfies the constraints for `rule`.
    /// Use this for submit-button guards and error messages.
    static func validate(_ value: String, rule: Rule) -> Bool {
        guard let pattern = patterns[rule] else { return false }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }

    // MARK: - Filter (whitelist, real-time)

    /// Returns a copy of `value` with all characters NOT in the rule's allowed
    /// set removed, then truncated to the rule's maximum length.
    /// Designed for real-time use inside `.onChange` — does not validate format.
    static func filter(_ value: String, rule: Rule) -> String {
        guard let allowed = allowedCharsets[rule],
              let maxLen  = maxLengths[rule] else { return value }

        let stripped = value.unicodeScalars
            .filter { allowed.contains($0) }
            .reduce(into: "") { $0.append(Character($1)) }

        // Truncate by grapheme cluster count (handles multi-scalar emoji safely)
        if stripped.count > maxLen {
            return String(stripped.prefix(maxLen))
        }
        return stripped
    }

    // MARK: - HTML Entity Encoding

    /// Encodes the five critical HTML characters to prevent XSS.
    ///
    /// Use this before:
    /// - Embedding any user string into a WKWebView HTML template
    /// - Sending free-text fields to Cloud Functions that may render HTML
    ///
    /// - Important: Call **once** per string. Double-encoding `&` → `&amp;amp;`.
    static func htmlEncoded(_ value: String) -> String {
        // Order matters: encode & first to avoid double-encoding subsequent entities.
        value
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'",  with: "&#x27;")
    }

    // MARK: - Parameterized Query Helper (SwiftData / NSPredicate)

    /// Returns a case-insensitive, diacritic-insensitive `NSPredicate` that
    /// treats `searchTerm` as **data**, never as executable predicate code.
    ///
    /// ✅ Correct — uses `%@` binding:
    /// ```swift
    /// let pred = InputValidator.safePredicate(field: "name", searchTerm: userInput)
    /// ```
    ///
    /// ❌ Never do this:
    /// ```swift
    /// NSPredicate(format: "name CONTAINS '\(userInput)'")  // injection risk
    /// ```
    ///
    /// - Note: Firestore's Swift SDK is already injection-safe by design; this
    ///   helper is for any local SwiftData `@Query` or `FetchDescriptor` predicate.
    static func safePredicate(field: String, searchTerm: String) -> NSPredicate {
        // %K binds the key path safely; %@ binds the value safely.
        NSPredicate(format: "%K CONTAINS[cd] %@", field, searchTerm)
    }
}
