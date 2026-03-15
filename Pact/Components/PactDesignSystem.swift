//
//  PactDesignSystem.swift
//  Pact
//
//  Color tokens, typography helpers, and spacing constants for the dark redesign.
//

import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let pactBackground  = Color(hex: "0A0A0A")   // deep black
    static let pactSurface     = Color(hex: "141414")   // elevated card
    static let pactSurface2    = Color(hex: "1E1E1E")   // nested card
    static let pactSurface3    = Color(hex: "1A1A1A")   // tab bar / badges
    static let pactAccent      = Color(hex: "D4AF6A")   // warm gold
    static let pactAccentSoft  = Color(hex: "F5E6C8")   // warm cream
    static let pactTextPrimary = Color.white
    static let pactTextSecond  = Color(hex: "888888")   // secondary labels
    static let pactTextMuted   = Color(hex: "444444")   // tertiary / placeholders
    static let pactGreen       = Color(hex: "34C759")   // approved
    static let pactAmber       = Color(hex: "FF9F0A")   // pending
    static let pactRed         = Color(hex: "FF453A")   // rejected / missed

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Gold Gradient

extension LinearGradient {
    static let pactGold = LinearGradient(
        colors: [Color(hex: "F0D080"), Color(hex: "D4AF6A"), Color(hex: "B8943E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let pactGoldSubtle = LinearGradient(
        colors: [Color(hex: "D4AF6A"), Color(hex: "B8943E")],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography

enum PactFont {
    /// 160pt black rounded — streak hero number
    static let streakDisplay = Font.system(size: 160, weight: .black, design: .rounded)
    /// 64pt compact hero
    static let streakCompact = Font.system(size: 64, weight: .black, design: .rounded)
    /// 32pt hero heading
    static let heading = Font.system(size: 32, weight: .bold)
    /// 20pt section title
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    /// 17pt card title
    static let cardTitle = Font.system(size: 17, weight: .bold)
    /// 15pt body medium
    static let body = Font.system(size: 15, weight: .medium)
    /// 13pt secondary body
    static let bodySmall = Font.system(size: 13, weight: .medium)
    /// 12pt caption
    static let caption = Font.system(size: 12, weight: .medium)
    /// 10pt micro label
    static let micro = Font.system(size: 10, weight: .bold)
}

// MARK: - Submission Status Helpers

extension Submission {
    var statusColor: Color {
        switch status {
        case "approved", "auto_approved": return .pactGreen
        case "rejected":                  return .pactRed
        default:                          return .pactAmber
        }
    }

    var statusLabel: String {
        switch status {
        case "approved", "auto_approved": return "Approved"
        case "rejected":                  return "Rejected"
        default:
            return "Awaiting Votes · \(approvalsReceived) of \(approvalsRequired) needed"
        }
    }

    var isApproved: Bool {
        status == "approved" || status == "auto_approved"
    }
}

// MARK: - Continuous corner radius modifier

extension View {
    func pactCard(_ radius: CGFloat = 20) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.pactSurface2)
        )
    }
}
