//
//  HomeScreenView.swift
//  Pact
//

import SwiftUI

// MARK: - Tab Definition

enum AppTab {
    case home, upload, team
}

// MARK: - Root Container

struct HomeScreenView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            // Active screen fills edge-to-edge
            Group {
                switch selectedTab {
                case .home:   HomeView()
                case .upload: UploadView()
                case .team:   TeamView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating liquid-glass tab bar
            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            // Home
            tabButton(tab: .home, icon: "house", selectedIcon: "house.fill")

            // Upload (center raised button)
            Button {
                selectedTab = .upload
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(white: selectedTab == .upload ? 0.85 : 0.93))
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(white: 0.25))
                }
                .offset(y: -10)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Team
            tabButton(tab: .team, icon: "person", selectedIcon: "person.fill")
        }
        .frame(width: 300, height: 72)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.65))
                .glassEffect(in: Capsule())
                .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 8)
        }
    }

    @ViewBuilder
    private func tabButton(tab: AppTab, icon: String, selectedIcon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: selectedTab == tab ? selectedIcon : icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(selectedTab == tab ? Color.black : Color(white: 0.45))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HomeScreenView()
}
