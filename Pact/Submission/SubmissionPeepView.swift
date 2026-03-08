//
//  SubmissionPeepView.swift
//  Pact
//
//  Bottom sheet shown when a user taps a pending or rejected submission card
//  in their "My Submissions Today" carousel.  Displays the proof photo, metadata,
//  a per-member vote breakdown, and nudge buttons for teammates who haven't voted.

import SwiftUI

struct SubmissionPeepView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    let submission: Submission

    @State private var votes: [String: String] = [:]          // voterUid → "approve"|"reject"
    @State private var isLoadingVotes = true
    @State private var nudgedUids: Set<String> = []            // disabled after one nudge per session
    @State private var sendingNudgeUids: Set<String> = []      // shows ProgressView while in-flight
    @State private var showCamera = false

    // MARK: - Computed

    private var todayDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: firestoreService.adminTimezone ?? "America/New_York")
        return fmt.string(from: Date())
    }

    private var submittedTimeString: String {
        guard let date = submission.createdAt else { return "–" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        fmt.amSymbol = "AM"
        fmt.pmSymbol = "PM"
        return fmt.string(from: date)
    }

    /// Team members who are eligible to vote on this submission (opted-in to the same activity,
    /// excluding the submitter themselves).
    private var eligibleVoters: [TeamMember] {
        firestoreService.members.filter { member in
            guard member.id != submission.submitterUid else { return false }
            // Members with no opted-in activities are treated as opted-in to everything
            if member.optedInActivityIds.isEmpty { return true }
            return member.optedInActivityIds.contains(submission.activityId)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // Proof photo
                CachedProofImage(urlString: submission.photoUrl, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Metadata card
                metadataCard

                // Votes section
                votesSection

                // Replace photo button (rejected only)
                if submission.status == "rejected" {
                    replacePhotoButton
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await loadVotes()
        }
        .fullScreenCover(isPresented: $showCamera) {
            UploadProofView(preselectActivityId: submission.activityId)
        }
    }

    // MARK: - Metadata card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Activity name row
            HStack(spacing: 8) {
                Image(systemName: activityIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                Text(submission.activityName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
            }

            Divider()
                .overlay(Color(white: 0.90))

            // Time submitted
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.55))
                Text("Submitted at \(submittedTimeString)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.50))
            }

            // Status pill
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                Text(statusLabel)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusBackground, in: Capsule())

            // Approval count (pending only)
            if submission.status == "pending" {
                let required = max(1, submission.approvalsRequired)
                Text("\(submission.approvalsReceived) of \(required) teammates approved")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.50))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.97))
        )
    }

    // MARK: - Votes section

    @ViewBuilder
    private var votesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Votes")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)

            if isLoadingVotes {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if eligibleVoters.isEmpty {
                Text("No other members are committed to this activity.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.55))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(eligibleVoters) { member in
                        voterRow(member: member)
                        if member.id != eligibleVoters.last?.id {
                            Divider()
                                .padding(.leading, 60)
                                .overlay(Color(white: 0.92))
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.97))
                )
            }
        }
    }

    @ViewBuilder
    private func voterRow(member: TeamMember) -> some View {
        let voteValue = votes[member.id]          // nil = not voted yet
        let hasVoted = voteValue != nil
        let approved = voteValue == "approve"
        let nudged = nudgedUids.contains(member.id)
        let sending = sendingNudgeUids.contains(member.id)

        HStack(spacing: 12) {
            // Avatar
            Image(member.avatarAssetName.isEmpty ? "avatar_felix" : member.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            // Name + vote label
            VStack(alignment: .leading, spacing: 2) {
                Text(member.nickname.isEmpty ? member.displayName : member.nickname)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                if hasVoted {
                    Text(approved ? "Approved" : "Rejected")
                        .font(.system(size: 12))
                        .foregroundStyle(approved
                            ? Color(red: 0.10, green: 0.55, blue: 0.25)
                            : Color(red: 0.75, green: 0.15, blue: 0.10))
                } else {
                    Text("Hasn't voted yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.55))
                }
            }

            Spacer()

            // Vote indicator or nudge button
            if hasVoted {
                Image(systemName: approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(approved
                        ? Color(red: 0.10, green: 0.55, blue: 0.25)
                        : Color(red: 0.75, green: 0.15, blue: 0.10))
            } else {
                nudgeButton(for: member, nudged: nudged, sending: sending)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func nudgeButton(for member: TeamMember, nudged: Bool, sending: Bool) -> some View {
        Button {
            Task { await nudge(memberUid: member.id) }
        } label: {
            Group {
                if sending {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 60, height: 28)
                } else {
                    Text(nudged ? "Sent!" : "Nudge")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(nudged ? Color(white: 0.55) : .black)
                        .frame(width: 60, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(nudged ? Color(white: 0.90) : Color(white: 0.88))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(nudged || sending)
    }

    // MARK: - Replace photo button

    private var replacePhotoButton: some View {
        Button {
            showCamera = true
        } label: {
            Text("Replace Photo")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadVotes() async {
        isLoadingVotes = true
        guard let teamId = firestoreService.currentTeamId else {
            isLoadingVotes = false
            return
        }
        votes = await firestoreService.fetchSubmissionVotes(
            teamId: teamId,
            date: todayDateString,
            submissionId: submission.id
        )
        isLoadingVotes = false
    }

    private func nudge(memberUid: String) async {
        guard let teamId = firestoreService.currentTeamId else { return }
        sendingNudgeUids.insert(memberUid)
        do {
            try await firestoreService.sendNudge(
                teamId: teamId,
                date: todayDateString,
                submissionId: submission.id,
                targetUid: memberUid
            )
        } catch {
            // Silently fail — nudge is best-effort
        }
        sendingNudgeUids.remove(memberUid)
        nudgedUids.insert(memberUid)
    }

    // MARK: - Style helpers

    private var activityIcon: String { "figure.run" }

    private var statusIcon: String {
        switch submission.status {
        case "approved", "auto_approved": return "checkmark.circle.fill"
        case "rejected":                  return "xmark.circle.fill"
        default:                          return "clock.fill"
        }
    }

    private var statusLabel: String {
        switch submission.status {
        case "approved", "auto_approved": return "Approved"
        case "rejected":                  return "Rejected"
        default:                          return "Pending"
        }
    }

    private var statusForeground: Color {
        switch submission.status {
        case "approved", "auto_approved": return Color(red: 0.10, green: 0.50, blue: 0.10)
        case "rejected":                  return Color(red: 0.75, green: 0.15, blue: 0.10)
        default:                          return Color(red: 0.50, green: 0.38, blue: 0.00)
        }
    }

    private var statusBackground: Color {
        switch submission.status {
        case "approved", "auto_approved": return Color(red: 0.88, green: 0.97, blue: 0.88)
        case "rejected":                  return Color(red: 0.98, green: 0.89, blue: 0.88)
        default:                          return Color(red: 0.98, green: 0.96, blue: 0.86)
        }
    }
}

#Preview {
    SubmissionPeepView(submission: Submission(dictionary: [
        "submissionId": "uid_act1",
        "submitterUid": "uid",
        "activityId": "act1",
        "displayName": "Test User",
        "nickname": "ApexHawk150",
        "avatarAssetName": "avatar_felix",
        "activityName": "Morning Run",
        "status": "pending",
        "approvalsReceived": 1,
        "approvalsRequired": 2,
    ])!)
    .environmentObject(FirestoreService())
}
