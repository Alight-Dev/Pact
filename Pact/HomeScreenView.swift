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
            Group {
                switch selectedTab {
                case .home:
                    HomeView(onTeamTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = .team
                        }
                    })
                case .upload: UploadView()
                case .team:   TeamView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            tabButton(tab: .home, icon: "house", selectedIcon: "house.fill")

            // Upload (center raised button)
            Button {
                onUploadTapped()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.93))
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
        .padding(.horizontal, 6)
        .frame(height: 70)
        // Outer liquid glass pill
        .glassEffect(in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 28, x: 0, y: 10)
    }

    @ViewBuilder
    private func tabButton(
        tab: AppTab,
        icon: String,
        selectedIcon: String,
        weight: Font.Weight = .regular
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HomeScreenView()
}
