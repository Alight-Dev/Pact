//
//  ProfileView.swift
//  Pact
//

import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import AuthenticationServices

// MARK: - Mock data (screen time & activity stats for visual pop until backend wired)

private let mockStreak        = 12
private let mockCompletion    = 87   // %
private let mockDaysSaved     = 8
private let mockAwakePercent  = 22
// Hours per day: Mon–Sun (week); 28 days (month)
private let mockWeekData: [Double]  = [2.5, 3.1, 4.2, 2.8, 3.5, 2.9, 3.0]
private let mockMonthData: [Double] = [3.2, 2.8, 3.5, 4.0, 2.6, 3.8, 3.1,
                                       2.9, 3.4, 3.0, 4.1, 2.7, 3.3, 3.6,
                                       2.5, 3.1, 4.2, 2.8, 3.5, 2.9, 3.0,
                                       3.2, 3.8, 2.6, 3.1, 4.0, 2.7, 3.5]

// MARK: - TimePeriod

private enum TimePeriod: String, CaseIterable {
    case week     = "Week"
    case month    = "Month"
    case lifetime = "Lifetime"
}

// MARK: - ProfileView

struct ProfileView: View {
    var onTeamTap: () -> Void = {}

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var selectedPeriod: TimePeriod = .week
    @State private var activeMembership: FirestoreService.ActiveMembership?
    @State private var showEditTeam = false
    @State private var showEditActivities = false
    @State private var showLeaveTeamConfirm = false
    @State private var showAdminPickerSheet = false
    @State private var selectedNewAdminUid: String? = nil
    @State private var isLeavingTeam = false
    @State private var leaveTeamError: String?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var isLoadingActivities = false
    @State private var activitySaveError: String?

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    private var isAdmin: Bool {
        guard let uid = currentUid else { return false }
        return firestoreService.members.first(where: { $0.id == uid })?.role == "admin"
    }

    private var otherMembers: [TeamMember] {
        guard let uid = currentUid else { return firestoreService.members }
        return firestoreService.members.filter { $0.id != uid }
    }

    private var nickname: String {
        UserDefaults.standard.string(forKey: "app_nickname") ?? "back"
    }

    /// First name for display at top; from Auth displayName, fallback to nickname.
    private var firstName: String {
        if let raw = authManager.currentUser?.displayName,
           let first = raw.split(separator: " ").first {
            return String(first)
        }
        return nickname
    }

    private var avatarAssetName: String {
        if let stored = UserDefaults.standard.string(forKey: "app_avatar_asset") {
            return stored
        }
        return "avatar_\(persistedAvatar)"
    }

    private var persistedAvatar: String {
        let key = "app_avatar"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let names = ["felix", "mia", "sam", "alex", "jordan", "riley", "avery",
                     "quinn", "morgan", "taylor", "casey", "blake", "drew",
                     "sage", "skyler", "river", "storm", "nova", "zara", "kai"]
        let pick = names.randomElement() ?? "felix"
        UserDefaults.standard.set(pick, forKey: key)
        return pick
    }

    private var teamName: String {
        firestoreService.currentTeamName
            ?? UserDefaults.standard.string(forKey: "app_team_name")
            ?? "Your Team"
    }

    private var shieldTier: String {
        let t = activeMembership?.shieldTier ?? ""
        return t.isEmpty ? "—" : t
    }

    private var streakDays: Int {
        activeMembership?.currentStreakDays ?? 0
    }

    private var teamMemberAvatars: [String] {
        firestoreService.members
            .map(\.avatarAssetName)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header outside ScrollView so sheet dismiss gesture works from top
            ProfileHeaderSection(
                firstName: firstName,
                username: nickname,
                avatarAssetName: avatarAssetName,
                shieldTier: shieldTier,
                streakDays: streakDays
            )
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTimeCard(selectedPeriod: $selectedPeriod)
                    ActivityStatsCard(
                        streakDays: mockStreak,
                        completionPercent: mockCompletion,
                        daysSaved: mockDaysSaved
                    )
                    TeamCard(
                        teamName: teamName,
                        shieldTier: shieldTier,
                        memberAvatars: teamMemberAvatars,
                        onTap: onTeamTap
                    )

                    ProfileSettingsSection(
                        isAdmin: isAdmin,
                        showEditActivities: !isAdmin && firestoreService.currentTeamId != nil,
                        onEditActivities: { showEditActivities = true },
                        onEditTeam: { showEditTeam = true },
                        onSignOut: { try? authManager.signOut() },
                        onLeaveTeam: {
                            selectedNewAdminUid = nil
                            if isAdmin && !otherMembers.isEmpty {
                                showAdminPickerSheet = true
                            } else {
                                showLeaveTeamConfirm = true
                            }
                        },
                        onDeleteAccount: { showDeleteConfirm = true }
                    )
                    .alert("Leave Team?", isPresented: $showLeaveTeamConfirm) {
                        Button("Leave", role: .destructive) {
                            guard let teamId = firestoreService.currentTeamId else { return }
                            Task {
                                isLeavingTeam = true
                                do {
                                    try await firestoreService.leaveTeam(teamId: teamId)
                                    firestoreService.clearTeamSession()
                                } catch {
                                    leaveTeamError = error.localizedDescription
                                }
                                isLeavingTeam = false
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        if firestoreService.members.count <= 1 {
                            Text("You are the only member. Leaving will permanently delete this team.")
                        } else {
                            Text("You will leave this team. Other members will not be affected.")
                        }
                    }
                    .alert("Could Not Leave Team", isPresented: .init(
                        get: { leaveTeamError != nil },
                        set: { if !$0 { leaveTeamError = nil } }
                    )) {
                        Button("OK", role: .cancel) { leaveTeamError = nil }
                    } message: {
                        Text(leaveTeamError ?? "")
                    }
                    .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive) {
                            Task {
                                isDeleting = true
                                do {
                                    // Leave the team first so Firestore reflects
                                    // the departure on all other members' devices.
                                    // Use try? — if leave fails (already removed,
                                    // network error) we still proceed with deletion.
                                    if let teamId = firestoreService.currentTeamId {
                                        try? await firestoreService.leaveTeam(teamId: teamId)
                                    }
                                    firestoreService.clearTeamSession()
                                    if authManager.providerID == "apple.com" {
                                        try await authManager.deleteAccountWithApple()
                                    } else {
                                        try await authManager.deleteAccount()
                                    }
                                } catch let error as ASAuthorizationError where error.code == .canceled {
                                    // User cancelled Apple re-auth — do nothing
                                } catch {
                                    deleteError = error.localizedDescription
                                }
                                isDeleting = false
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This permanently deletes your account. You will be removed from your team and all local app data will be cleared. This cannot be undone.")
                    }
                    .alert("Delete Failed", isPresented: .init(
                        get: { deleteError != nil },
                        set: { if !$0 { deleteError = nil } }
                    )) {
                        Button("OK", role: .cancel) { deleteError = nil }
                    } message: {
                        Text(deleteError ?? "")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.white)
        .presentationDragIndicator(.visible)
        .task {
            activeMembership = try? await firestoreService.loadActiveMembership()
            await loadOptedInActivities()
        }
        .sheet(isPresented: $showAdminPickerSheet) {
            AdminPickerSheet(
                members: otherMembers,
                selectedUid: $selectedNewAdminUid,
                onConfirm: { uid in
                    showAdminPickerSheet = false
                    guard let teamId = firestoreService.currentTeamId else { return }
                    Task {
                        isLeavingTeam = true
                        do {
                            try await firestoreService.leaveTeam(teamId: teamId, newAdminUid: uid)
                            firestoreService.clearTeamSession()
                        } catch {
                            leaveTeamError = error.localizedDescription
                        }
                        isLeavingTeam = false
                    }
                },
                onCancel: { showAdminPickerSheet = false }
            )
        }
        .sheet(isPresented: $showEditTeam) {
            EditTeamView()
                .environmentObject(firestoreService)
        }
        .sheet(isPresented: $showEditActivities) {
            EditActivitiesView(
                activities: firestoreService.teamActivities,
                optedInIds: $firestoreService.optedInActivityIds,
                isLoading: isLoadingActivities,
                saveError: activitySaveError,
                onToggle: { toggleActivity($0) }
            )
        }
    }

    private func loadOptedInActivities() async {
        guard let teamId = firestoreService.currentTeamId else { return }
        isLoadingActivities = true
        await firestoreService.loadOptedInActivityIds(teamId: teamId)
        isLoadingActivities = false
    }

    private func toggleActivity(_ activityId: String) {
        let wasSelected = firestoreService.optedInActivityIds.contains(activityId)

        if wasSelected && firestoreService.optedInActivityIds.count <= 1 {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                activitySaveError = "You must be opted into at least one activity."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if activitySaveError == "You must be opted into at least one activity." {
                    withAnimation { activitySaveError = nil }
                }
            }
            return
        }

        activitySaveError = nil
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if wasSelected {
                firestoreService.optedInActivityIds.remove(activityId)
            } else {
                firestoreService.optedInActivityIds.insert(activityId)
            }
        }

        guard let teamId = firestoreService.currentTeamId else { return }
        Task {
            do {
                try await firestoreService.updateOptedInActivities(
                    teamId: teamId,
                    activityIds: Array(firestoreService.optedInActivityIds)
                )
            } catch {
                withAnimation {
                    if wasSelected {
                        firestoreService.optedInActivityIds.insert(activityId)
                    } else {
                        firestoreService.optedInActivityIds.remove(activityId)
                    }
                    activitySaveError = "Failed to save. Try again."
                }
            }
        }
    }
}

// MARK: - EditActivitiesView

private struct EditActivitiesView: View {
    let activities: [TeamActivity]
    @Binding var optedInIds: Set<String>
    let isLoading: Bool
    let saveError: String?
    let onToggle: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Select the activities you want to commit to. You must stay opted into at least one.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.55))
                            .lineSpacing(3)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Spacer()
                            }
                            .padding(.vertical, 40)
                        } else if activities.isEmpty {
                            Text("No activities set up yet.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(activities) { activity in
                                    activityRow(activity)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if let error = saveError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func activityRow(_ activity: TeamActivity) -> some View {
        let isSelected = optedInIds.contains(activity.id)

        Button {
            onToggle(activity.id)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : Color(white: 0.93))
                        .frame(width: 44, height: 44)

                    Image(systemName: activity.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .black)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)

                    if !activity.activityDescription.isEmpty {
                        Text(activity.activityDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color(white: 0.55))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .white : Color(white: 0.78))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.black : Color(white: 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.black.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ProfileHeaderSection

private struct ProfileHeaderSection: View {
    let firstName: String
    let username: String
    let avatarAssetName: String
    let shieldTier: String
    let streakDays: Int

    private var usernameDisplay: String {
        let base = username.lowercased().replacingOccurrences(of: " ", with: "")
        return base.isEmpty ? "@user" : "@\(base)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First name + gear row
            HStack {
                Text(firstName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }

            // Avatar
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.green, lineWidth: 3))

            // Username
            Text(usernameDisplay)
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.50))

            // Tier + streak pills
            HStack(spacing: 8) {
                Text("\(shieldTier) Tier")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green, in: Capsule())

                Text("🔥 \(streakDays) day streak")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.92), in: Capsule())
            }
        }
    }
}

// MARK: - ScreenTimeCard

/// Uses mock screen time data so the card pops until backend is wired.
private struct ScreenTimeCard: View {
    @Binding var selectedPeriod: TimePeriod

    private var avgTimeText: String {
        let data: [Double]
        switch selectedPeriod {
        case .week:     data = mockWeekData
        case .month:    data = mockMonthData
        case .lifetime: return "N/A"
        }
        let avg     = data.reduce(0, +) / Double(data.count)
        let hours   = Int(avg)
        let minutes = Int((avg - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Screen Time")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            // Period picker
            HStack(spacing: 6) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedPeriod == period ? .white : Color.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedPeriod == period ? Color.black : Color(white: 0.92))
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedPeriod)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(avgTimeText)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.black)
                Text("Avg Daily  ·  \(mockAwakePercent)% of awake time")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.50))
            }

            ScreenTimeBarChart(selectedPeriod: selectedPeriod)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - ScreenTimeBarChart

private struct ScreenTimeBarChart: View {
    let selectedPeriod: TimePeriod

    private var data: [Double] {
        switch selectedPeriod {
        case .week:     return mockWeekData
        case .month:    return mockMonthData
        case .lifetime: return []
        }
    }

    private let weekLabels    = ["M", "T", "W", "T", "F", "S", "S"]
    private let barAreaHeight: CGFloat = 120
    private let labelHeight: CGFloat   = 20

    private var todayIndex: Int {
        switch selectedPeriod {
        case .week:     return 3
        case .month:    return data.count - 1
        case .lifetime: return -1
        }
    }

    var body: some View {
        if selectedPeriod == .lifetime {
            Text("Coming soon")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.55))
                .frame(maxWidth: .infinity, minHeight: 120)
                .multilineTextAlignment(.center)
        } else {
            GeometryReader { geo in
                let bars   = data
                let count  = bars.count
                let gap: CGFloat = count > 7 ? 3 : 6
                let barW   = (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count)
                let maxVal = max(bars.max() ?? 0, 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: gap) {
                        ForEach(Array(bars.enumerated()), id: \.offset) { i, val in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(i == todayIndex ? Color.black : Color(white: 0.85))
                                .frame(width: barW,
                                       height: max(4, barAreaHeight * CGFloat(val / maxVal)))
                        }
                    }
                    .frame(height: barAreaHeight)
                    .animation(.easeInOut(duration: 0.25), value: selectedPeriod)

                    if selectedPeriod == .week {
                        HStack(spacing: gap) {
                            ForEach(Array(weekLabels.enumerated()), id: \.offset) { _, label in
                                Text(label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.55))
                                    .frame(width: barW)
                            }
                        }
                    }
                }
            }
            .frame(height: selectedPeriod == .week ? 148 : 120)
        }
    }
}

// MARK: - ActivityStatsCard

/// Uses mock stats so the card pops until backend is wired.
private struct ActivityStatsCard: View {
    let streakDays: Int
    let completionPercent: Int
    let daysSaved: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Stats")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            HStack(spacing: 0) {
                statCell(symbol: "flame.fill",
                         color: .black,
                         value: "\(streakDays)",
                         label: "Day Streak")
                Divider()
                statCell(symbol: "checkmark.circle.fill",
                         color: .green,
                         value: "\(completionPercent)%",
                         label: "Completion")
                Divider()
                statCell(symbol: "lock.shield.fill",
                         color: .black,
                         value: "\(daysSaved)",
                         label: "Days Saved")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        )
    }

    private func statCell(symbol: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - TeamCard

private struct TeamCard: View {
    let teamName: String
    let shieldTier: String
    let memberAvatars: [String]
    var onTap: () -> Void = {}

    private let overlap: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Team")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            HStack(spacing: 12) {
                ZStack {
                    ForEach(Array(memberAvatars.enumerated()), id: \.offset) { i, name in
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: CGFloat(i) * overlap)
                    }
                }
                .frame(width: max(36, 36 + overlap * CGFloat(max(0, memberAvatars.count - 1))), height: 36)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(teamName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("\(shieldTier) Tier")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.97))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture { onTap() }
        }
    }
}

// MARK: - ProfileSettingsSection

private struct ProfileSettingsSection: View {
    var isAdmin: Bool
    var showEditActivities: Bool = false
    var onEditActivities: () -> Void = {}
    var onEditTeam: () -> Void
    var onSignOut: () -> Void
    var onLeaveTeam: () -> Void
    var onDeleteAccount: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Edit Profile")
            if showEditActivities {
                Divider()
                Button(action: onEditActivities) {
                    settingsRow(title: "Edit Activities")
                }
                .buttonStyle(.plain)
            }
            Divider()
            settingsRow(title: "Notifications")
            if isAdmin {
                Divider()
                Button(action: onEditTeam) {
                    settingsRow(title: "Edit Team")
                }
                .buttonStyle(.plain)
            }
            Divider()
            Button(action: onLeaveTeam) {
                settingsRow(title: "Leave Team", isRed: true, showChevron: false)
            }
            .buttonStyle(.plain)
            Divider()
            Button(action: onSignOut) {
                settingsRow(title: "Sign Out", isRed: true, showChevron: false)
            }
            .buttonStyle(.plain)
            Divider()
            Button(action: onDeleteAccount) {
                settingsRow(title: "Delete Account", isRed: true, showChevron: false)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        )
    }

    private func settingsRow(title: String, isRed: Bool = false, showChevron: Bool = true) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(isRed ? Color.red : Color.black)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

// MARK: - AdminPickerSheet

/// Presented when an admin wants to leave a team that still has other members.
/// The admin must select a successor before the leave is finalised.
private struct AdminPickerSheet: View {
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

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(FirestoreService())
}
