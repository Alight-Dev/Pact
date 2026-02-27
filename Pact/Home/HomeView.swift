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
// TODO: Wire ringProgress to today's activity completion ratio (completed/total) from SwiftData or Firestore.
private let ringProgress: CGFloat  = 0.35
// TODO: Wire health score to real weekly streak data from Firestore.
private let scoreProgress: CGFloat = 0.80   // 4 out of 5

// TODO: Replace teamAvatars with real member avatar assets from FirestoreService.currentTeam members.
private let teamAvatars = ["felix", "mia", "sam", "alex"]

// MARK: - HomeView

struct HomeView: View {
    var onTeamTap: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @Query(sort: [SortDescriptor(\Activity.order), SortDescriptor(\Activity.createdAt)])
    private var activities: [Activity]

    @State private var cardSelection: Int = carouselStart
    @State private var animatedProgress: CGFloat = 0
    @State private var showProfile = false

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

    // TODO: Replace with real-time FirestoreService.currentTeam["name"] once listeners are started post-onboarding.
    private var teamName: String {
        UserDefaults.standard.string(forKey: "app_team_name") ?? "Your Team"
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "E0E0E0"), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome \(nickname)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(white: 0.55))

                            Text(firstName)
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
                        .sheet(isPresented: $showProfile) { ProfileView() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // MARK: Progress Ring + Logo
                    HStack {
                        Spacer()
                        ZStack {
                            // Track ring (light grey)
                            Circle()
                                .stroke(Color(white: 0.88), lineWidth: ringWidth)
                                .frame(width: ringDiameter, height: ringDiameter)

                            // Progress arc (black, flat ends)
                            Circle()
                                .trim(from: 0, to: animatedProgress)
                                .stroke(
                                    Color.black,
                                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
                                )
                                .frame(width: ringDiameter, height: ringDiameter)
                                .rotationEffect(.degrees(-90))

                            // Pact logo centred inside the ring
                            Image("PactLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoSize, height: logoSize)
                        }
                        Spacer()
                    }
                    .padding(.top, 24)
                    .onAppear {
                        withAnimation(.timingCurve(0.19, 1, 0.22, 1, duration: 1.8).delay(0.3)) {
                            animatedProgress = ringProgress
                        }
                    }
                    .onDisappear {
                        animatedProgress = 0
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
                    .frame(height: 200)
                    .padding(.top, 20)

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
                    .padding(.top, 10)

                    // MARK: Today's Goal
                    todayGoalCard
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Bottom breathing room for the tab bar
                    Spacer(minLength: 110)
                }
            }
        }
    }

    // MARK: - Card views

    @ViewBuilder
    private func cardView(for card: HomeCard) -> some View {
        switch card {
        case .healthScore:   healthScoreCard
        case .teamProgress:  teamProgressCard
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
                    Text(activities.first?.name ?? "No activities yet")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.50))
                }
            }
            .padding(.bottom, 14)

            Divider()
                .padding(.bottom, 14)

            // Activity list
            VStack(spacing: 14) {
                if activities.isEmpty {
                    Text("No activities set up yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                } else {
                    ForEach(activities) { activity in
                        activityRow(title: activity.name, completed: false)
                        // TODO: Replace `completed: false` with real submission status from
                        //       FirestoreService.todaysSubmissions once Firestore is deployed.
                    }
                }
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 14)

            // Your completion label + count
            HStack {
                Text("Your Completion")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.50))
                Spacer()
                // TODO: Replace 0 with count of approved submissions from Firestore.
                Text("0/\(activities.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .padding(.bottom, 8)

            // TODO: Replace 0.0 with real completion fraction (approvedCount / activities.count).
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.88))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.black)
                        .frame(width: geo.size.width * 0.0, height: 8)
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
}

