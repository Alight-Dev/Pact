//
//  VoteQueueCardView.swift
//  Pact
//
//  Compact vote card shown in lift sheet full state — pending submissions needing a vote.
//

import SwiftUI
import FirebaseAuth

struct VoteQueueCardView: View {
    let submission: Submission
    let teamId: String
    let onVote: (String) -> Void  // "approved" | "rejected"

    @State private var voted = false

    private var alreadyVoted: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return submission.voterIds.contains(uid)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView
                .frame(width: 44, height: 44)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(submission.nickname.isEmpty ? submission.displayName : submission.nickname)
                    .font(PactFont.body)
                    .foregroundStyle(Color.pactTextPrimary)
                    .lineLimit(1)
                Text(submission.activityName)
                    .font(PactFont.caption)
                    .foregroundStyle(Color.pactTextSecond)
                    .lineLimit(1)
            }

            Spacer()

            // Vote buttons
            if voted || alreadyVoted {
                Text("Voted")
                    .font(PactFont.caption)
                    .foregroundStyle(Color.pactTextMuted)
            } else {
                HStack(spacing: 8) {
                    voteButton(icon: "xmark", color: .pactRed, vote: "rejected")
                    voteButton(icon: "checkmark", color: .pactGreen, vote: "approved")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.pactSurface2)
        )
    }

    // MARK: - Sub-views

    private func voteButton(icon: String, color: Color, vote: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { voted = true }
            onVote(vote)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(color.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarView: some View {
        if !submission.avatarAssetName.isEmpty,
           UIImage(named: submission.avatarAssetName) != nil {
            Image(submission.avatarAssetName)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.pactSurface3)
                .overlay(
                    Text(initials(submission.nickname.isEmpty
                                  ? submission.displayName
                                  : submission.nickname))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.pactAccent)
                )
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(1)).uppercased()
    }
}
