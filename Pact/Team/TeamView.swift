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
            CachedProofImage(urlString: highlight.photoUrl)
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
            CachedProofImage(urlString: submission.photoUrl)
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
    let onVote: (String, String) -> Void  // (submissionId, vote)

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
                        onVote(submission.id, approved ? "approve" : "reject")
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

// MARK: - Share Invite Sheet

private struct ShareInviteSheet: UIViewControllerRepresentable {
    let inviteCode: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let link = "pact://join/\(inviteCode)"
        return UIActivityViewController(
            activityItems: [
                "Join my Pact Shield! 🛡️\nCode: \(inviteCode)\n\(link)",
                URL(string: link)!
            ],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Shield Members Section

private struct ShieldMembersSection: View {
    let inviteCode: String
    let members: [ShieldMember]
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Shield Members")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    showShareSheet = true
                } label: {
                    Label("Add Members", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.94), in: Capsule())
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareInviteSheet(inviteCode: inviteCode)
                        .ignoresSafeArea()
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
    @State private var mySubmissionPage = 0
    @State private var pendingSubmissions: [Submission] = []
    @State private var submissionToPeep: Submission? = nil
    @State private var showLeaveSheet = false
    @State private var showAdminPickerSheet = false
    @State private var selectedNewAdminUid: String? = nil
    @State private var isLeavingTeam = false
    @State private var leaveTeamError: String? = nil

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    private var isAdmin: Bool {
        guard let uid = currentUid else { return false }
        return firestoreService.members.first(where: { $0.id == uid })?.role == "admin"
    }

    private var otherMembers: [TeamMember] {
        guard let uid = currentUid else { return firestoreService.members }
        return firestoreService.members.filter { $0.id != uid }
    }
    
    private var inviteCode: String {
        if let live = firestoreService.currentTeam?["inviteCode"] as? String { return live }
        if let cached = UserDefaults.standard.string(forKey: "app_invite_code") { return cached }
        return "------"
    }

    /// Maps live Firestore members → ShieldMember for display.
    /// Uses each member's optedInActivityIds count so the X/Y counter
    /// reflects the activities they actually joined, not the full team total.
    private var liveMembers: [ShieldMember] {
        let currentUid = Auth.auth().currentUser?.uid
        let allTotal = firestoreService.teamActivities.count
        let approved = firestoreService.mappedSubmissions.filter {
            $0.status == "approved" || $0.status == "auto_approved"
        }
        return firestoreService.members.map { member in
            let memberTotal = member.optedInActivityIds.isEmpty
                ? allTotal
                : member.optedInActivityIds.count
            let requiredActivityIds: Set<String> = member.optedInActivityIds.isEmpty
                ? Set(firestoreService.teamActivities.map(\.id))
                : Set(member.optedInActivityIds)
            let completedCount = approved.filter {
                $0.submitterUid == member.id && requiredActivityIds.contains($0.activityId)
            }.count
            return ShieldMember(
                memberName: member.nickname.isEmpty ? member.displayName : member.nickname,
                memberAvatarAsset: member.avatarAssetName.isEmpty ? "avatar_felix" : member.avatarAssetName,
                activitiesCompleted: completedCount,
                activitiesTotal: max(memberTotal, 1),
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

    private var myTodaySubmissions: [Submission] {
        guard let uid = currentUid else { return [] }
        func statusPriority(_ status: String) -> Int {
            switch status {
            case "rejected":                    return 0
            case "pending":                     return 1
            case "approved", "auto_approved":   return 2
            default:                            return 3
            }
        }
        return firestoreService.mappedSubmissions
            .filter { $0.submitterUid == uid }
            .sorted {
                let pa = statusPriority($0.status), pb = statusPriority($1.status)
                if pa != pb { return pa < pb }
                // Within same status: activityId is a Firestore auto-ID (roughly chronological)
                return $0.activityId > $1.activityId
            }
    }

    @ViewBuilder
    private var mySubmissionsSection: some View {
        if !myTodaySubmissions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("My Submissions Today")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                TabView(selection: $mySubmissionPage) {
                    ForEach(Array(myTodaySubmissions.enumerated()), id: \.element.id) { index, sub in
                        mySubmissionCard(sub)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 84)

                if myTodaySubmissions.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(myTodaySubmissions.indices, id: \.self) { index in
                            Circle()
                                .fill(index == mySubmissionPage ? Color.black : Color(white: 0.80))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func mySubmissionCard(_ sub: Submission) -> some View {
        let isTappable = sub.status == "pending" || sub.status == "rejected"
        let cardContent = HStack(spacing: 12) {
            // Proof photo thumbnail
            Group {
                if let urlString = sub.photoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color(white: 0.88)
                        }
                    }
                } else {
                    Color(white: 0.88)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.activityName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                // Status pill
                let (pillText, pillColor) = mySubmissionPillInfo(sub)
                Text(pillText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(pillColor, in: Capsule())
            }

            Spacer()

            // Chevron hint for tappable states
            if isTappable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.70))
            }
        }
        .padding(12)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        if isTappable {
            Button {
                submissionToPeep = sub
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }

    private func mySubmissionPillInfo(_ sub: Submission) -> (String, Color) {
        switch sub.status {
        case "approved", "auto_approved":
            return ("Approved", Color(red: 0.10, green: 0.65, blue: 0.35))
        case "rejected":
            return ("Rejected", Color(red: 0.75, green: 0.15, blue: 0.10))
        default:
            let text = "Pending · \(sub.approvalsReceived)/\(sub.approvalsRequired) approved"
            return (text, Color(red: 0.75, green: 0.58, blue: 0.00))
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
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TeamShieldHeader(
                        teamName: shieldDisplayName,
                        memberCount: firestoreService.members.count,
                        tier: ShieldTier.current(for: firestoreService.currentTeam?["currentStreakDays"] as? Int ?? 0),
                        streakDays: firestoreService.currentTeam?["currentStreakDays"] as? Int ?? 0
                    )
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                    // Highlights — always visible at the top of the feed
                    HighlightsSection(highlights: approvedSubmissions)
                        .padding(.top, 32)
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))

                    // My submissions today
                    mySubmissionsSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                        .transition(.opacity)

                    // Pending approvals — only shown when the user has items to vote on
                    if !pendingSubmissions.isEmpty {
                        PendingApprovalsSection(submissions: $pendingSubmissions, onVote: handleVote)
                            .padding(.top, myTodaySubmissions.isEmpty ? 32 : 24)
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                    }

                    ShieldMembersSection(inviteCode: inviteCode, members: membersToShow)
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
        .sheet(isPresented: $showAdminPickerSheet) {
            TeamAdminPickerSheet(
                members: otherMembers,
                selectedUid: $selectedNewAdminUid,
                onConfirm: { uid in
                    showAdminPickerSheet = false
                    performLeave(newAdminUid: uid)
                },
                onCancel: { showAdminPickerSheet = false }
            )
        }
        .sheet(item: $submissionToPeep) { sub in
            SubmissionPeepView(submission: sub)
                .environmentObject(firestoreService)
        }
    }

    private func performLeave(newAdminUid: String?) {
        guard let teamId = firestoreService.currentTeamId else { return }
        isLeavingTeam = true
        Task {
            do {
                try await firestoreService.leaveTeam(teamId: teamId, newAdminUid: newAdminUid)
                await MainActor.run { firestoreService.clearTeamSession() }
            } catch {
                await MainActor.run { leaveTeamError = error.localizedDescription }
            }
            await MainActor.run { isLeavingTeam = false }
        }
    }

    private func refreshPending(from all: [Submission]) {
        let currentUid = Auth.auth().currentUser?.uid ?? ""
        pendingSubmissions = all.filter { sub in
            sub.status == "pending"
                && sub.submitterUid != currentUid
                // Layer 1 — synchronous, app-level: set immediately when the user
                // votes, before the async Firestore write. Survives tab switches
                // within the same app session.
                && !firestoreService.votedSubmissionIds.contains(sub.id)
                // Layer 2 — Firestore-backed: populated by castVote() arrayUnion.
                // Survives app restarts once the write has completed.
                && !sub.voterIds.contains(currentUid)
        }
    }

    private func handleVote(submissionId: String, vote: String) {
        // Mark as voted SYNCHRONOUSLY in the app-level store before any async
        // work — guarantees the card won't reappear on the next .onAppear even
        // if the user navigates away before the Firestore write completes.
        firestoreService.votedSubmissionIds.insert(submissionId)

        guard let teamId = firestoreService.currentTeamId else { return }
        let date = FirestoreService.todayString(in: firestoreService.adminTimezone ?? "UTC")
        Task {
            try? await firestoreService.castVote(
                teamId: teamId,
                date: date,
                submissionId: submissionId,
                vote: vote
            )
        }
    }
}

// MARK: - Team Shield Header

private struct TeamShieldHeader: View {
    let teamName: String
    let memberCount: Int
    let tier: ShieldTier
    let streakDays: Int

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

            // Tier + streak (live from Firestore)
            HStack(spacing: 6) {
                if tier != .none {
                    Text("\(tier.rawValue) Tier")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tier.color)

                    Text("•")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(white: 0.65))
                }

                Text(streakDays == 1 ? "1 day streak" : "\(streakDays) day streak")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.50))
            }
        }
    }
}

// MARK: - TeamAdminPickerSheet

private struct TeamAdminPickerSheet: View {
    let members: [TeamMember]
    @Binding var selectedUid: String?
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            List(members) { member in
                Button {
                    selectedUid = member.id
                } label: {
                    HStack(spacing: 12) {
                        Image(member.avatarAssetName.isEmpty ? "avatar_felix" : member.avatarAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.nickname.isEmpty ? member.displayName : member.nickname)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                            if !member.displayName.isEmpty {
                                Text(member.displayName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(white: 0.55))
                            }
                        }

                        Spacer()

                        if selectedUid == member.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose New Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm & Leave") {
                        if let uid = selectedUid { onConfirm(uid) }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selectedUid != nil ? Color.red : Color(white: 0.55))
                    .disabled(selectedUid == nil)
                }
            }
        }
    }
}

#Preview {
    TeamView()
        .environmentObject(FirestoreService())
}
