//
//  TeamStatusRowView.swift
//  Pact
//
//  Avatar row with colored status dots — shown in lift sheet peek state.
//

import SwiftUI

struct TeamStatusRowView: View {
    let members: [TeamMember]
    let submissions: [Submission]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(members) { member in
                memberCell(member: member)
                if member.id != members.last?.id {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Member Cell

    private func memberCell(member: TeamMember) -> some View {
        let status = submissionStatus(for: member)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar
                avatarView(member: member)
                    .frame(width: 48, height: 48)

                // Status dot
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.pactSurface, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }

            Text(shortName(member.nickname.isEmpty ? member.displayName : member.nickname))
                .font(PactFont.caption)
                .foregroundStyle(Color.pactTextMuted)
                .lineLimit(1)
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatarView(member: TeamMember) -> some View {
        if !member.avatarAssetName.isEmpty,
           UIImage(named: member.avatarAssetName) != nil {
            Image(member.avatarAssetName)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.pactSurface, lineWidth: 2))
        } else {
            Circle()
                .fill(Color.pactSurface3)
                .overlay(
                    Text(initials(member.nickname.isEmpty ? member.displayName : member.nickname))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pactAccent)
                )
        }
    }

    // MARK: - Helpers

    private enum SubmissionStatus { case approved, pending, none }

    private func submissionStatus(for member: TeamMember) -> SubmissionStatus {
        let sub = submissions.first { $0.submitterUid == member.id }
        guard let sub else { return .none }
        return sub.isApproved ? .approved : .pending
    }

    private func statusColor(_ status: SubmissionStatus) -> Color {
        switch status {
        case .approved: return .pactGreen
        case .pending:  return .pactAmber
        case .none:     return Color.pactTextMuted
        }
    }

    private func shortName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name)).prefix(8).description
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.pactSurface.ignoresSafeArea()
        TeamStatusRowView(members: [], submissions: [])
            .padding(.vertical, 16)
    }
}
