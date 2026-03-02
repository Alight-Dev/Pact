//
//  TeamView.swift
//  Pact
//

import SwiftUI
import FirebaseAuth

// MARK: - Mock Data

private struct ShieldMember: Identifiable {
    let id = UUID()
    let memberName: String
    let memberAvatarAsset: String
    let activitiesCompleted: Int
    let activitiesTotal: Int
    let isCurrentUser: Bool

    var hasCompletedAll: Bool { activitiesCompleted >= activitiesTotal }
    var progress: Double { activitiesTotal > 0 ? Double(activitiesCompleted) / Double(activitiesTotal) : 0 }
}

// TODO: Replace with real team member data from FirestoreService.currentTeam members subcollection.
private let mockMembers: [ShieldMember] = [
    ShieldMember(memberName: "You",    memberAvatarAsset: "avatar_alex",   activitiesCompleted: 1, activitiesTotal: 3, isCurrentUser: true),
    ShieldMember(memberName: "Sarah",  memberAvatarAsset: "avatar_sara",   activitiesCompleted: 3, activitiesTotal: 3, isCurrentUser: false),
    ShieldMember(memberName: "Alex",   memberAvatarAsset: "avatar_alex",   activitiesCompleted: 0, activitiesTotal: 2, isCurrentUser: false),
    ShieldMember(memberName: "Jordan", memberAvatarAsset: "avatar_jordan", activitiesCompleted: 2, activitiesTotal: 2, isCurrentUser: false),
]



// MARK: - Highlight Card

private struct HighlightCard: View {
    let highlight: Submission

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let urlStr = highlight.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        default:
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.94))
                                .frame(height: 260)
                                .overlay { ProgressView().tint(Color(white: 0.55)) }
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.94))
                            .frame(height: 260)
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(white: 0.70))
                    }
                }
            }
            .frame(height: 260)
            .overlay(alignment: .topTrailing) {
                Text("APPROVED")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.20, green: 0.75, blue: 0.45), in: Capsule())
                    .padding(12)
            }

            HStack(spacing: 12) {
                Image(highlight.avatarAssetName.isEmpty ? "avatar_felix" : highlight.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(highlight.nickname.isEmpty ? highlight.displayName : highlight.nickname)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(highlight.activityName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.20, green: 0.75, blue: 0.45))
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Highlights Section

private struct HighlightsSection: View {
    let highlights: [Submission]
    @State private var currentPage = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Highlights")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            if highlights.isEmpty {
                Text("No highlights yet — be the first to complete a goal!")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                TabView(selection: $currentPage) {
                    ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                        HighlightCard(highlight: highlight)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 370)

                HStack(spacing: 6) {
                    ForEach(highlights.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.black : Color(white: 0.80))
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Submission Card

private struct SubmissionCard: View {
    let submission: Submission
    let onSwipe: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragIsHorizontal: Bool? = nil

    private var approveOpacity: Double {
        max(0, min(1, Double(offset.width) / 80))
    }

    private var rejectOpacity: Double {
        max(0, min(1, Double(-offset.width) / 80))
    }

    private var rotation: Double {
        Double(offset.width / 300) * 25
    }

    var body: some View {
        VStack(spacing: 0) {
            // Photo area
            Group {
                if let urlStr = submission.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        default:
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.94))
                                .frame(height: 260)
                                .overlay {
                                    ProgressView().tint(Color(white: 0.55))
                                }
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.94))
                            .frame(height: 260)
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(white: 0.70))
                    }
                }
            }
            .frame(height: 260)
            .overlay(alignment: .topLeading) {
                // APPROVE label
                Text("APPROVE")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.green, in: Capsule())
                    .rotationEffect(.degrees(-15))
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    .opacity(approveOpacity)
            }
            .overlay(alignment: .topTrailing) {
                // REJECT label
                Text("REJECT")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.red, in: Capsule())
                    .rotationEffect(.degrees(15))
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                    .opacity(rejectOpacity)
            }

            // Info row
            HStack(spacing: 12) {
                Image(submission.avatarAssetName.isEmpty ? "avatar_felix" : submission.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(submission.nickname.isEmpty ? submission.displayName : submission.nickname)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(submission.activityName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                }

                Spacer()

                Text("\(submission.approvalsReceived)/\(submission.approvalsRequired) approvals")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.55))
            }
            .padding(.top, 14)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    flyOff(approved: false)
                } label: {
                    Label("Reject", systemImage: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    flyOff(approved: true)
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 16)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .offset(x: offset.width, y: 0)
        .rotationEffect(.degrees(rotation))
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if dragIsHorizontal == nil {
                        let isH = abs(value.translation.width) > abs(value.translation.height)
                        dragIsHorizontal = isH
                    }
                    guard dragIsHorizontal == true else { return }
                    isDragging = true
                    offset = CGSize(width: value.translation.width, height: 0)
                }
                .onEnded { value in
                    let wasHorizontal = dragIsHorizontal == true
                    dragIsHorizontal = nil
                    isDragging = false
                    if wasHorizontal && abs(value.translation.width) > 120 {
                        flyOff(approved: value.translation.width > 0)
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            offset = .zero
                        }
                    }
                }
        )
        .animation(isDragging ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: offset)
    }

    private func flyOff(approved: Bool) {
        let targetX: CGFloat = approved ? 600 : -600
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: targetX, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(approved)
        }
    }
}

// MARK: - Swipeable Card Stack

private struct SwipeableCardStack: View {
    @Binding var submissions: [Submission]
    let onVote: (String, String) -> Void

    var body: some View {
        let visible = Array(submissions.prefix(3))
        ZStack {
            ForEach(Array(visible.enumerated().reversed()), id: \.element.id) { index, submission in
                let isTop = index == 0
                let depth = index
                let scale = 1.0 - (Double(depth) * 0.03)
                let yOffset = Double(depth) * 10

                SubmissionCard(
                    submission: submission,
                    onSwipe: { approved in
                        onVote(submission.submitterUid, approved ? "approve" : "reject")
                        withAnimation(.spring()) {
                            submissions.removeAll { $0.id == submission.id }
                        }
                    }
                )
                .scaleEffect(isTop ? 1.0 : scale)
                .offset(y: isTop ? 0 : yOffset)
                .zIndex(Double(visible.count - depth))
            }
        }
    }
}

// MARK: - Pending Approvals Section

private struct PendingApprovalsSection: View {
    @Binding var submissions: [Submission]
    let onVote: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pending Approvals")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            SwipeableCardStack(submissions: $submissions, onVote: onVote)
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: ShieldMember

    var body: some View {
        HStack(spacing: 12) {
            Image(member.memberAvatarAsset)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        member.hasCompletedAll ? Color(red: 0.20, green: 0.75, blue: 0.45) : Color.clear,
                        lineWidth: 2.5
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(member.memberName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    if member.isCurrentUser {
                        Text("You")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.20, green: 0.75, blue: 0.45), in: Capsule())
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Spacer()
                        Text("\(member.activitiesCompleted)/\(member.activitiesTotal)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(white: 0.55))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(white: 0.88))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color(red: 0.20, green: 0.75, blue: 0.45))
                                .frame(width: geo.size.width * member.progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }

            Spacer()

            Circle()
                .fill(member.hasCompletedAll ? Color(red: 0.20, green: 0.75, blue: 0.45) : Color(white: 0.78))
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Shield Members Section

private struct ShieldMembersSection: View {
    let shareURL: URL
    let members: [ShieldMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Shield Members")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                // Share a URL so iMessage (and other apps) render it as a tappable link
                ShareLink(item: shareURL) {
                    Label("Add Members", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.94), in: Capsule())
                }
            }

            VStack(spacing: 8) {
                ForEach(members) { member in
                    MemberRow(member: member)
                }
            }
        }
    }
}

// MARK: - Team View

struct TeamView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var pendingSubmissions: [Submission] = []
    @State private var votedIds: Set<String> = []
    
    private var inviteShareURL: URL {
        // Use the live invite code from Firestore when available,
        // or the one cached in UserDefaults from the last team session,
        // otherwise fall back to a placeholder so the button is always visible.
        let code: String
        if let live = firestoreService.currentTeam?["inviteCode"] as? String {
            code = live
        } else if let cached = UserDefaults.standard.string(forKey: "app_invite_code") {
            code = cached
        } else {
            code = "------"
        }
        // Sharing a URL (not a String) makes iMessage render it as a tappable link
        return URL(string: "pact://join/\(code)")!
    }

    /// Maps live Firestore members → ShieldMember for display.
    private var liveMembers: [ShieldMember] {
        let currentUid = Auth.auth().currentUser?.uid
        let total = firestoreService.teamActivities.count
        return firestoreService.members.map { member in
            ShieldMember(
                memberName: member.nickname.isEmpty ? member.displayName : member.nickname,
                memberAvatarAsset: member.avatarAssetName.isEmpty ? "avatar_felix" : member.avatarAssetName,
                activitiesCompleted: 0,   // TODO: wire to real submission counts
                activitiesTotal: max(total, 1),
                isCurrentUser: member.id == currentUid
            )
        }
    }

    /// Falls back to mock data only on the very first render before listeners load.
    private var membersToShow: [ShieldMember] {
        liveMembers.isEmpty ? mockMembers : liveMembers
    }

    private var approvedSubmissions: [Submission] {
        firestoreService.mappedSubmissions.filter {
            $0.status == "approved" || $0.status == "auto_approved"
        }
    }

    private var shieldDisplayName: String {
        if let name = firestoreService.currentTeam?["name"] as? String {
            return name
        }
        if let cached = firestoreService.currentTeamName {
            return cached
        }
        if let local = UserDefaults.standard.string(forKey: "app_team_name") {
            return local
        }
        return "Your Team"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TeamShieldHeader(teamName: shieldDisplayName, memberCount: firestoreService.members.count)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                if !pendingSubmissions.isEmpty {
                    PendingApprovalsSection(submissions: $pendingSubmissions, onVote: handleVote)
                        .padding(.top, 32)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                } else {
                    HighlightsSection(highlights: approvedSubmissions)
                        .padding(.top, 32)
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                ShieldMembersSection(shareURL: inviteShareURL, members: membersToShow)
                    .padding(.top, 32)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .onChange(of: firestoreService.mappedSubmissions) { _, newSubmissions in
            refreshPending(from: newSubmissions)
        }
        .onAppear {
            refreshPending(from: firestoreService.mappedSubmissions)
        }
    }

    private func refreshPending(from all: [Submission]) {
        let currentUid = Auth.auth().currentUser?.uid
        pendingSubmissions = all.filter { sub in
            sub.status == "pending"
                && sub.submitterUid != currentUid
                && !votedIds.contains(sub.submitterUid)
        }
    }

    private func handleVote(submitterUid: String, vote: String) {
        votedIds.insert(submitterUid)
        guard let teamId = firestoreService.currentTeamId else { return }
        let date = FirestoreService.todayDateString()
        Task {
            try? await firestoreService.castVote(
                teamId: teamId,
                date: date,
                submitterUid: submitterUid,
                vote: vote
            )
        }
    }
}

// MARK: - Team Shield Header

private struct TeamShieldHeader: View {
    let teamName: String
    let memberCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Shield icon + title
            HStack(spacing: 8) {
                Image("GreenShard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)

                Text(teamName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
            }

            // Member count
            Text(memberCount == 1 ? "1 member" : "\(memberCount) members")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.50))

            // Tier + streak
            HStack(spacing: 6) {
                Text("Emerald Tier")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.75, blue: 0.45))

                Text("•")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.65))

                Text("12 day streak")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.50))
            }
        }
    }
}

#Preview {
    TeamView()
        .environmentObject(FirestoreService())
}
