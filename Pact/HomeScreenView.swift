//
//  HomeScreenView.swift
//  Pact
//

import SwiftUI
import UserNotifications

// MARK: - Tab Definition

enum AppTab {
    case home, team
}

// MARK: - Root Container

struct HomeScreenView: View {
    @EnvironmentObject var notificationRouter: NotificationRouter
    @State private var selectedTab: AppTab = .home
    @State private var showUpload: Bool = false
    #if DEBUG
    @State private var debugNotifIndex: Int = 0
    private let debugNotifTypes = ["vote_needed", "submission_approved", "daily_complete"]
    #endif

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                ZStack {
                    switch selectedTab {
                    case .home:
                        HomeView(onTeamTap: {
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                                selectedTab = .team
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                    case .team:
                        TeamView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .trailing)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                FloatingTabBar(selectedTab: $selectedTab, onUploadTapped: {
                    showUpload = true
                })
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .bottom)

            // In-app notification banner
            if let banner = notificationRouter.activeBanner {
                InAppNotificationBanner(
                    payload: banner,
                    onTap: {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                            selectedTab = banner.tab
                        }
                        notificationRouter.activeBanner = nil
                    },
                    onDismiss: {
                        notificationRouter.activeBanner = nil
                    }
                )
                .zIndex(999)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.82),
                           value: notificationRouter.activeBanner != nil)
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                // Instant in-app banner (cycles through types)
                Button {
                    let type = debugNotifTypes[debugNotifIndex % debugNotifTypes.count]
                    debugNotifIndex += 1
                    NotificationCenter.default.post(
                        name: .pactNotification,
                        object: nil,
                        userInfo: [
                            "type": type,
                            "title": titleFor(type),
                            "body": bodyFor(type),
                            "submitterNickname": "Alex",
                            "activityName": "Morning Run",
                            "submitterUid": "",
                            "_foreground": "1",
                        ]
                    )
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }

                // Real iOS push notification in 10 seconds — background the app to see it
                Button {
                    scheduleTestLocalNotification()
                } label: {
                    Image(systemName: "clock.badge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(Color.indigo.opacity(0.85)))
                }
            }
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
        #endif
        .fullScreenCover(isPresented: $showUpload) {
            UploadProofView()
        }
        .onChange(of: notificationRouter.pendingTabSwitch) { _, tab in
            guard let tab else { return }
            withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                selectedTab = tab
            }
            notificationRouter.pendingTabSwitch = nil
        }
    }

    #if DEBUG
    private func scheduleTestLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Submission"
        content.body = "Alex submitted Morning Run. Tap to vote →"
        content.sound = .default
        content.userInfo = [
            "type": "vote_needed",
            "submitterNickname": "Alex",
            "activityName": "Morning Run",
            "submitterUid": "",
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: "debug-test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Debug] Failed to schedule notification: \(error)")
            } else {
                print("[Debug] Test notification scheduled — fires in 10 seconds")
            }
        }
    }

    private func titleFor(_ type: String) -> String {
        switch type {
        case "vote_needed":         return "New Submission"
        case "submission_approved": return "Proof approved! 🎉"
        case "daily_complete":      return "Pact complete! 🔥"
        default:                    return "Pact"
        }
    }
    private func bodyFor(_ type: String) -> String {
        switch type {
        case "vote_needed":         return "Alex submitted Morning Run. Tap to vote →"
        case "submission_approved": return "Your team voted you in. Keep the streak alive!"
        case "daily_complete":      return "Every teammate finished today. Streak safe!"
        default:                    return ""
        }
    }
    #endif
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    var onUploadTapped: () -> Void

    var body: some View {
        GeometryReader { proxy in
            HStack {
                Spacer()

                HStack(spacing: 0) {
                    tabButton(tab: .home, icon: "house", selectedIcon: "house.fill")

                    // Upload — same style as the tab buttons, no selected state
                    Button {
                        onUploadTapped()
                    } label: {
                        ZStack {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color(white: 0.50))
                        }
                        .frame(width: 94, height: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    tabButton(tab: .team, icon: "person.2", selectedIcon: "person.2.fill")
                }
                .padding(.horizontal, 6)
                .frame(width: proxy.size.width * (2.2 / 3.0), height: 70)
                // Outer liquid glass pill
                .glassEffect(in: Capsule())
                .shadow(color: .black.opacity(0.14), radius: 28, x: 0, y: 10)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
        }
        .frame(height: 70)
    }

    @ViewBuilder
    private func tabButton(
        tab: AppTab,
        icon: String,
        selectedIcon: String,
        weight: Font.Weight = .regular
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                // Inner glass pill for the selected state (glass-within-glass)
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(width: 80, height: 52)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                Image(systemName: selectedTab == tab ? selectedIcon : icon)
                    .font(.system(size: 22, weight: weight))
                    .foregroundStyle(selectedTab == tab ? Color.black : Color(white: 0.50))
            }
            .frame(width: 94, height: 54)
            .contentShape(Rectangle())          // makes transparent areas tappable
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // hit area fills full bar height
    }
}

// MARK: - Preview

#Preview {
    HomeScreenView()
}
