//
//  HomeView.swift
//  Pact
//

import SwiftUI

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
private let ringProgress: CGFloat  = 0.35
private let scoreProgress: CGFloat = 0.80   // 4 out of 5

private let teamAvatars = ["felix", "mia", "sam", "alex"]

// MARK: - HomeView

struct HomeView: View {
    var onTeamTap: () -> Void

    @State private var cardSelection: Int = carouselStart

    private var currentDot: Int { cardSelection % cardCount }

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
                            Text("Welcome Ethan!")
                                .font(.subheadline)
                                .foregroundStyle(Color(white: 0.55))

                            Text("Money Team")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)
                                .onTapGesture { onTeamTap() }
                        }

                        Spacer()

                        Image("avatar_\(persistedAvatar)")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
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
                                .trim(from: 0, to: ringProgress)
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
            Text("Team Progress")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)

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
}
