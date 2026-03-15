//
//  HeroView.swift
//  Pact
//
//  Top hero section: animated streak number, tier badge, stats row, CTA.
//

import SwiftUI
import FirebaseAuth

struct HeroView: View {
    let teamName: String
    let streak: Int
    let shieldVM: ShieldProgressViewModel
    let todaysSubmissions: [Submission]
    let userActivities: [TeamActivity]
    let onAvatarTap: () -> Void
    let onSubmitTap: () -> Void

    // Compact mode for when lift sheet is expanded
    var compact: Bool = false

    @State private var ctaAppeared = false

    // MARK: - Computed

    private var uid: String? { Auth.auth().currentUser?.uid }

    private var mySubmission: Submission? {
        guard let uid else { return nil }
        return todaysSubmissions.first { $0.submitterUid == uid }
    }

    private var approvedCount: Int {
        todaysSubmissions.filter { $0.isApproved }.count
    }

    private var ctaState: CTAState {
        guard let sub = mySubmission else { return .notSubmitted }
        switch sub.status {
        case "approved", "auto_approved": return .approved
        case "rejected": return .notSubmitted  // allow retry
        default:
            return .pendingVotes(received: sub.approvalsReceived, required: sub.approvalsRequired)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "GOOD MORNING"
        case 12..<17: return "GOOD AFTERNOON"
        case 17..<21: return "GOOD EVENING"
        default:      return "GOOD NIGHT"
        }
    }

    private var tierLabel: String {
        if shieldVM.isMaxTier {
            return "✦ \(shieldVM.currentTier.rawValue.uppercased()) TIER · MAX"
        } else if let next = shieldVM.nextTier {
            return "✦ \(shieldVM.currentTier.rawValue.uppercased()) TIER · \(shieldVM.daysUntilNextTier)d to \(next.rawValue)"
        }
        return "✦ \(shieldVM.currentTier.rawValue.uppercased()) TIER"
    }

    // MARK: - Body

    var body: some View {
        if compact {
            compactHero
        } else {
            fullHero
        }
    }

    // MARK: - Full Hero

    private var fullHero: some View {
        VStack(spacing: 0) {
            // Top bar: greeting + avatar button
            HStack {
                Text(greeting)
                    .font(PactFont.micro)
                    .foregroundStyle(Color.pactTextSecond)
                    .kerning(1.5)
                Spacer()
                Button(action: onAvatarTap) {
                    Circle()
                        .fill(Color.pactSurface2)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.pactTextSecond)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            Spacer()

            // Streak number — hero element
            StreakNumberView(targetStreak: streak, fontSize: 140)
                .padding(.bottom, -20)

            // "DAY STREAK" label
            Text("DAY STREAK")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.pactAccentSoft.opacity(0.7))
                .kerning(3)

            Spacer().frame(height: 16)

            // Tier badge
            Text(tierLabel)
                .font(PactFont.caption)
                .foregroundStyle(Color.pactAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.pactSurface3)
                )

            Spacer().frame(height: 14)

            // Stats row
            HStack(spacing: 20) {
                statPill(label: "\(approvedCount)/\(userActivities.count) Approved", icon: "checkmark")
                if shieldVM.streakDays > 0 {
                    statPill(label: "Best: \(streak) Days", icon: "flame.fill")
                }
            }

            Spacer().frame(height: 24)

            // CTA Button
            ctaButton
                .padding(.horizontal, 28)

            Spacer().frame(height: 60)
        }
    }

    // MARK: - Compact Hero

    private var compactHero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(teamName.uppercased()) · \(shieldVM.currentTier.rawValue.uppercased()) TIER")
                    .font(PactFont.micro)
                    .foregroundStyle(Color.pactTextSecond)
                    .kerning(1)
            }
            Spacer()
            Text("\(streak)")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient.pactGold)
            if ctaState == .approved {
                Label("All Done", systemImage: "checkmark.circle.fill")
                    .font(PactFont.caption)
                    .foregroundStyle(Color.pactGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.pactGreen.opacity(0.15)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func statPill(label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(PactFont.caption)
        }
        .foregroundStyle(Color.pactTextSecond)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.pactSurface))
    }

    @ViewBuilder
    private var ctaButton: some View {
        switch ctaState {
        case .notSubmitted:
            Button(action: onSubmitTap) {
                Label("Submit Proof", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pactBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.pactGold, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)

        case .pendingVotes(let received, let required):
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                Text("Awaiting Votes · \(received)/\(required)")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.pactAmber)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule(style: .continuous)
                    .stroke(Color.pactAmber.opacity(0.4), lineWidth: 1.5)
                    .background(Capsule(style: .continuous).fill(Color.pactSurface))
            )

        case .approved:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text("All Done Today ✓")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.pactGreen)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.pactGreen.opacity(0.12))
            )
        }
    }
}

// MARK: - CTA State

private enum CTAState: Equatable {
    case notSubmitted
    case pendingVotes(received: Int, required: Int)
    case approved
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.pactBackground.ignoresSafeArea()
        VStack {
            HeroView(
                teamName: "Team Alpha",
                streak: 12,
                shieldVM: ShieldProgressViewModel(),
                todaysSubmissions: [],
                userActivities: [],
                onAvatarTap: {},
                onSubmitTap: {}
            )
        }
    }
}
