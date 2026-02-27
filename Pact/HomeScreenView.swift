//
//  HomeScreenView.swift
//  Pact
//

import SwiftUI

// MARK: - Tab Definition

enum AppTab {
    case home, team
}

// MARK: - Root Container

struct HomeScreenView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showUpload: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .team:
                    TeamView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating liquid-glass tab bar
            FloatingTabBar(selectedTab: $selectedTab, onUploadTapped: {
                showUpload = true
            })
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showUpload) {
            UploadProofView()
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    var onUploadTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Home
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
        .frame(maxWidth: .infinity)
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

