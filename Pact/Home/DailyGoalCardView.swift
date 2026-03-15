//
//  DailyGoalCardView.swift
//  Pact
//
//  Today's goal card with hero-sized proof photo or submit CTA.
//

import SwiftUI

struct DailyGoalCardView: View {
    let activity: TeamActivity
    let submission: Submission?
    let onSubmitTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Proof photo hero (if submitted)
            if let url = submission?.photoUrl, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    case .failure, .empty:
                        photoPlaceholder
                    @unknown default:
                        photoPlaceholder
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 20,
                        style: .continuous
                    )
                )
            }

            // Card body
            VStack(alignment: .leading, spacing: 10) {
                // Goal icon + name
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.pactBackground)
                            .frame(width: 36, height: 36)
                        Image(systemName: activity.iconName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pactAccent)
                    }
                    Text(activity.name)
                        .font(PactFont.cardTitle)
                        .foregroundStyle(Color.pactTextPrimary)
                    Spacer()
                }

                // Status
                if let sub = submission {
                    statusRow(sub)
                } else {
                    noSubmissionRow
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.pactSurface2)
        )
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func statusRow(_ sub: Submission) -> some View {
        HStack {
            Text(sub.statusLabel)
                .font(PactFont.bodySmall)
                .foregroundStyle(sub.statusColor)

            Spacer()

            if !sub.isApproved && sub.status != "rejected" {
                Text("\(sub.approvalsReceived)/\(sub.approvalsRequired)")
                    .font(PactFont.caption)
                    .foregroundStyle(Color.pactAmber)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.pactAmber.opacity(0.15))
                    )
            }
        }
    }

    private var noSubmissionRow: some View {
        Button(action: onSubmitTap) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Submit Proof")
                    .font(PactFont.body)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.pactAccent)
        }
        .buttonStyle(.plain)
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color.pactSurface3)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.pactTextMuted)
                    Text("Proof Photo")
                        .font(PactFont.caption)
                        .foregroundStyle(Color.pactTextMuted)
                }
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.pactBackground.ignoresSafeArea()
        DailyGoalCardView(
            activity: TeamActivity.preview,
            submission: nil,
            onSubmitTap: {}
        )
        .padding(20)
    }
}

// MARK: - Preview helper

extension TeamActivity {
    static let preview = TeamActivity(
        id: "1", name: "Morning Workout",
        iconName: "figure.run", activityDescription: "",
        repeatDays: [], order: 0
    )

    init(id: String, name: String, iconName: String, activityDescription: String, repeatDays: [Int], order: Int) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.activityDescription = activityDescription
        self.repeatDays = repeatDays
        self.order = order
    }
}
