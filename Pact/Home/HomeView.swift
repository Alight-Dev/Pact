//
//  HomeView.swift
//  Pact
//

import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Carousel data

private enum HomeCard { case healthScore, teamProgress }
private let cardCount = 2
private let carouselItems: [HomeCard] = Array(
    repeating: [HomeCard.healthScore, .teamProgress], count: 100
).flatMap { $0 }
private let carouselStart = 100   // index 100 → .healthScore  (100 % 2 == 0)

// MARK: - Ring / score constants

private let ringDiameter: CGFloat  = 190
private let ringWidth: CGFloat     = 14
private let logoSize: CGFloat      = 100
// ringProgress is now driven by ShieldProgressViewModel (no hardcoded value).
// TODO: Wire health score to real weekly streak data from Firestore.
private let scoreProgress: CGFloat = 0.80   // 4 out of 5

// TODO: Replace teamAvatars with real member avatar assets from FirestoreService.currentTeam members.
private let teamAvatars = ["felix", "mia", "sam", "alex"]

// MARK: - HomeView

struct HomeView: View {
    var onTeamTap: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreService: FirestoreService
    @Query(sort: [SortDescriptor(\Activity.order), SortDescriptor(\Activity.createdAt)])
    private var activities: [Activity]

    /// Prefers live Firestore activities filtered to the user's opted-in set.
    /// Falls back to all team activities when optedInActivityIds is empty (admin/creator).
    /// Falls back to SwiftData only when no session is running.
    private var displayActivities: [TeamActivity] {
        firestoreService.userActivities
    }

    @StateObject private var shieldVM = ShieldProgressViewModel()

    @State private var cardSelection: Int = carouselStart
    @State private var animatedProgress: CGFloat = 0
    @State private var showProfile = false
    @State private var switchToTeamAfterDismiss = false

    private var currentDot: Int { cardSelection % cardCount }

    private var nickname: String {
        UserDefaults.standard.string(forKey: "app_nickname") ?? "back"
    }

    private var avatarAssetName: String {
        if let stored = UserDefaults.standard.string(forKey: "app_avatar_asset") {
            return stored
        }
        // Fallback for users who onboarded before avatar persistence was added.
        return "avatar_\(persistedAvatar)"
    }

    private var firstName: String {
        if let raw = authManager.currentUser?.displayName,
           let first = raw.split(separator: " ").first {
            return String(first)
        }
        return nickname
    }

    private var teamName: String {
        if let name = firestoreService.currentTeam?["name"] as? String { return name }
        if let cached = firestoreService.currentTeamName { return cached }
        return UserDefaults.standard.string(forKey: "app_team_name") ?? "Your Team"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "F8F8F8")
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome \(firstName)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(white: 0.55))

                            Text(teamName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)
                                .onTapGesture { onTeamTap() }
                        }

                        Spacer()

                        Button { showProfile = true } label: {
                            Image(avatarAssetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showProfile, onDismiss: {
                            if switchToTeamAfterDismiss {
                                switchToTeamAfterDismiss = false
                                onTeamTap()
                            }
                        }) {
                            ProfileView(onTeamTap: {
                                switchToTeamAfterDismiss = true
                                showProfile = false
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // MARK: Progress Ring + Streak
                    VStack(spacing: 14) {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .stroke(Color(white: 0.88), lineWidth: ringWidth)
                                    .frame(width: ringDiameter, height: ringDiameter)

                                Circle()
                                    .trim(from: 0, to: animatedProgress)
                                    .stroke(
                                        Color.black,
                                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                                    )
                                    .frame(width: ringDiameter, height: ringDiameter)
                                    .rotationEffect(.degrees(-90))

                                VStack(spacing: 2) {
                                    Text("\(shieldVM.streakDays)")
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundStyle(.black)
                                    Text("Day Streak")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color(white: 0.55))
                                }
                            }
                            Spacer()
                        }

                        Text(shieldVM.currentTier.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)

                        if shieldVM.isMaxTier {
                            Text("Max Tier Achieved")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.55))
                        } else if shieldVM.currentTier == .none {
                            Text("Start your streak to earn a rank")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.55))
                        } else if let next = shieldVM.nextTier {
                            Text("\(shieldVM.daysUntilNextTier) days until \(next.rawValue)")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.55))
                        }
                    }
                    .padding(.top, 12)
                    .onAppear {
                        shieldVM.observe(firestoreService)
                    }
                    .onChange(of: shieldVM.progressToNextTier) { _, newValue in
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            animatedProgress = newValue
                        }
                    }

                    // MARK: Infinite swipe carousel
                    TabView(selection: $cardSelection) {
                        ForEach(Array(carouselItems.enumerated()), id: \.offset) { i, card in
                            cardView(for: card)
                                .padding(.horizontal, 20)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 300)
                    .padding(.top, 10)

                    // MARK: Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<cardCount, id: \.self) { i in
                            Circle()
                                .fill(i == currentDot ? Color.black : Color(white: 0.80))
                                .frame(width: 7, height: 7)
                                .animation(.easeInOut(duration: 0.2), value: currentDot)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)

                    // MARK: Today's Goal
                    todayGoalCard
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)

                    // Bottom breathing room for the tab bar
                    Spacer(minLength: 30)
                }
            }
        }
    }

    // MARK: - Card views

    @ViewBuilder
    private func cardView(for card: HomeCard) -> some View {
        switch card {
        case .healthScore:    healthScoreCard
        case .teamProgress:   teamProgressCard
        }
    }

    private var healthScoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Health Score")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                // TODO: Wire health score to real weekly streak data from Firestore.
                Text("4/5")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.88))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.black)
                        .frame(width: geo.size.width * scoreProgress, height: 8)
                }
            }
            .frame(height: 8)

            // TODO: Replace lorem ipsum with real health score description.
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.50))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    private var teamProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Team Progress")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(8)
                    .background(Color(white: 0.93), in: Circle())
            }

            HStack(spacing: 0) {
                ForEach(teamAvatars, id: \.self) { name in
                    Image("avatar_\(name)")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
        .onTapGesture { onTeamTap() }
    }

    // MARK: - Submission completion helpers

    /// Activity IDs for which the current user has a peer-approved or auto-approved
    /// submission today. Used to tick off rows and fill the progress bar.
    private var myCompletedActivityIds: Set<String> {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return Set(
            firestoreService.mappedSubmissions
                .filter { $0.submitterUid == uid &&
                    ($0.status == "approved" || $0.status == "auto_approved") }
                .map { $0.activityId }
                .filter { !$0.isEmpty }
        )
    }

    /// Legacy: activity names for completion when activityId is missing (e.g. SwiftData fallback or old submissions).
    private var myCompletedActivityNames: Set<String> {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return Set(
            firestoreService.mappedSubmissions
                .filter { $0.submitterUid == uid &&
                    ($0.status == "approved" || $0.status == "auto_approved") }
                .map { $0.activityName }
        )
    }

    /// All of the current user's submissions for today (any status).
    private var myTodaySubmissions: [Submission] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return firestoreService.mappedSubmissions.filter { $0.submitterUid == uid }
    }

    // MARK: - Activity row helper

    @ViewBuilder
    private func activityRow(title: String, completed: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.black)
            Spacer()
            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
            } else {
                Rectangle()
                    .fill(Color(white: 0.50))
                    .frame(width: 12, height: 2)
                    .cornerRadius(1)
            }
        }
    }

    // MARK: - Submission status helpers

    private func submissionStatusIcon(for status: String) -> String {
        switch status {
        case "approved", "auto_approved": return "checkmark.circle.fill"
        case "rejected":                  return "xmark.circle.fill"
        default:                          return "clock.fill"
        }
    }

    private func submissionStatusColor(for status: String) -> Color {
        switch status {
        case "approved", "auto_approved": return Color(red: 0.10, green: 0.55, blue: 0.10)
        case "rejected":                  return Color(red: 0.75, green: 0.15, blue: 0.10)
        default:                          return Color(red: 0.75, green: 0.58, blue: 0.00)
        }
    }

    private func submissionStatusText(for sub: Submission) -> String {
        switch sub.status {
        case "approved", "auto_approved": return "Approved — Unlocked!"
        case "rejected":                  return "Rejected — tap + to retry"
        default:
            return "Pending · \(sub.approvalsReceived)/\(sub.approvalsRequired) approved"
        }
    }

    // MARK: - Today's Goal card

    private var todayGoalCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Icon + title/subtitle row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: "scope")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Goal")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                    Text(displayActivities.first?.name ?? activities.first?.name ?? "No activities yet")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.50))
                }
            }
            .padding(.bottom, 14)

            Divider()
                .padding(.bottom, 14)

            // Activity list — prefer live Firestore data, fall back to SwiftData
            VStack(spacing: 14) {
                if displayActivities.isEmpty && activities.isEmpty {
                    Text("No activities set up yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                } else if !displayActivities.isEmpty {
                    ForEach(displayActivities) { activity in
                        activityRow(
                            title: activity.name,
                            completed: myCompletedActivityIds.contains(activity.id)
                        )
                    }
                } else {
                    ForEach(activities) { activity in
                        activityRow(
                            title: activity.name,
                            completed: myCompletedActivityNames.contains(activity.name)
                        )
                    }
                }
            }
            .padding(.bottom, 16)

            // Submission status rows (one per submission today)
            if !myTodaySubmissions.isEmpty {
                Divider()
                    .padding(.bottom, 12)
                VStack(spacing: 10) {
                    ForEach(myTodaySubmissions) { sub in
                        HStack(spacing: 10) {
                            Image(systemName: submissionStatusIcon(for: sub.status))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(submissionStatusColor(for: sub.status))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sub.activityName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(white: 0.30))
                                Text(submissionStatusText(for: sub))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.50))
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 14)
            }

            Divider()
                .padding(.bottom, 14)

            // Your completion label + count (only count approved submissions for current opted-in activities)
            let totalActivities = displayActivities.isEmpty ? activities.count : displayActivities.count
            let completedCount = displayActivities.isEmpty
                ? myCompletedActivityNames.count
                : myCompletedActivityIds.intersection(Set(displayActivities.map(\.id))).count
            HStack {
                Text("Your Completion")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.50))
                Spacer()
                Text("\(completedCount)/\(totalActivities)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.88))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.black)
                        .frame(
                            width: geo.size.width * (totalActivities > 0
                                ? CGFloat(completedCount) / CGFloat(totalActivities)
                                : 0),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            .padding(.bottom, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Persisted avatar

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
}

// MARK: - Hex colour helper

private extension Color {
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

// MARK: - Preview

#Preview {
    HomeView(onTeamTap: {})
        .modelContainer(for: Activity.self, inMemory: true)
        .environmentObject(AuthManager())
        .environmentObject(FirestoreService())
}

