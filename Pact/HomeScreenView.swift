//
//  HomeScreenView.swift
//  Pact
//
//  Root container with dark floating tab bar (warm gold selected state).
//

import SwiftUI
import FirebaseAuth

// MARK: - Tab Definition

enum AppTab {
    case home, team
}

// MARK: - Root Container

struct HomeScreenView: View {
    @EnvironmentObject var notificationRouter: NotificationRouter
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedTab: AppTab = .home
    @State private var showUpload: Bool = false
    @State private var showAllDoneAlert: Bool = false

    private var allTasksCompleted: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let displayActivities = firestoreService.userActivities
        guard !displayActivities.isEmpty else { return false }
        let completedIds = Set(
            firestoreService.mappedSubmissions
                .filter { $0.submitterUid == uid &&
                    ($0.status == "approved" || $0.status == "auto_approved") }
                .map { $0.activityId }
                .filter { !$0.isEmpty }
        )
        let displayIds = Set(displayActivities.map(\.id))
        return completedIds.isSuperset(of: displayIds)
    }

    var body: some View {
        ZStack {
            Color.pactBackground.ignoresSafeArea()

            ZStack(alignment: .bottom) {
                // Tab content
                ZStack {
                    switch selectedTab {
                    case .home:
                        HomeView(onTeamTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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

                // Floating tab bar (dark pill)
                PactTabBar(
                    selectedTab: $selectedTab,
                    onUploadTapped: {
                        if allTasksCompleted {
                            showAllDoneAlert = true
                        } else {
                            showUpload = true
                        }
                    }
                )
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .bottom)

            // In-app notification banner
            if let banner = notificationRouter.activeBanner {
                InAppNotificationBanner(
                    payload: banner,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        .fullScreenCover(isPresented: $showUpload) {
            UploadProofView()
        }
        .alert("All Done!", isPresented: $showAllDoneAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've completed all your tasks for today. Come back tomorrow!")
        }
        .onChange(of: notificationRouter.pendingTabSwitch) { _, tab in
            guard let tab else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            notificationRouter.pendingTabSwitch = nil
        }
    }
}

// MARK: - Dark Floating Tab Bar

private struct PactTabBar: View {
    @Binding var selectedTab: AppTab
    var onUploadTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Home tab
            tabButton(tab: .home, icon: "house.fill", label: "HOME")

            // Upload button — centered gold circle
            Button(action: onUploadTapped) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.pactGold)
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.pactAccent.opacity(0.4), radius: 12, x: 0, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.pactBackground)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Team tab
            tabButton(tab: .team, icon: "person.2.fill", label: "TEAM")
        }
        .frame(width: 320, height: 68)
        .background(
            Capsule(style: .continuous)
                .fill(Color.pactSurface3)
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
        )
    }

    @ViewBuilder
    private func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedTab == tab ? Color.pactAccent : Color.pactTextMuted)

                Text(label)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(selectedTab == tab ? Color.pactAccent : Color.pactTextMuted)
                    .kerning(1)

                // Active indicator dot
                Circle()
                    .fill(Color.pactAccent)
                    .frame(width: 4, height: 4)
                    .opacity(selectedTab == tab ? 1 : 0)
                    .scaleEffect(selectedTab == tab ? 1 : 0.1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HomeScreenView()
        .environmentObject(NotificationRouter())
        .environmentObject(FirestoreService())
}
