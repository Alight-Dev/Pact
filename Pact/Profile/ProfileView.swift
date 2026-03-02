//
//  ProfileView.swift
//  Pact
//

import SwiftUI
import FirebaseAuth

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
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var isDeleting = false

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
                        onSignOut: { try? authManager.signOut() },
                        onDeleteAccount: { showDeleteConfirm = true }
                    )
                    .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive) {
                            Task {
                                isDeleting = true
                                do {
                                    firestoreService.stopListeners()
                                    try await authManager.deleteAccount()
                                } catch {
                                    deleteError = error.localizedDescription
                                }
                                isDeleting = false
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This permanently deletes your account and all local app data. Your Firestore team data is not removed. This cannot be undone.")
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
        }
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(teamName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("\(shieldTier) Tier")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                }

                Spacer()

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
    var onSignOut: () -> Void
    var onDeleteAccount: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Edit Profile")
            Divider()
            settingsRow(title: "Notifications")
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

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(FirestoreService())
}
