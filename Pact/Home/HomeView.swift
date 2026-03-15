//
//  HomeView.swift
//  Pact
//
//  Redesigned: Split hero + draggable lift sheet.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct HomeView: View {
    var onTeamTap: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreService: FirestoreService

    @StateObject private var shieldVM = ShieldProgressViewModel()
    @State private var sheetPosition: SheetPosition = .peek
    @State private var showProfile = false
    @State private var showUpload = false
    @State private var switchToTeamAfterDismiss = false

    // MARK: - Computed

    private var teamName: String {
        if let name = firestoreService.currentTeam?["name"] as? String { return name }
        if let cached = firestoreService.currentTeamName { return cached }
        return UserDefaults.standard.string(forKey: "app_team_name") ?? "Your Team"
    }

    private var teamId: String {
        firestoreService.currentTeamId ?? ""
    }

    private var streak: Int {
        shieldVM.streakDays
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background
                Color.pactBackground.ignoresSafeArea()

                // Hero — fills top, shrinks when sheet expands
                VStack {
                    HeroView(
                        teamName: teamName,
                        streak: streak,
                        shieldVM: shieldVM,
                        todaysSubmissions: firestoreService.mappedSubmissions,
                        userActivities: firestoreService.userActivities,
                        onAvatarTap: { showProfile = true },
                        onSubmitTap: { showUpload = true },
                        compact: sheetPosition == .full
                    )
                    .frame(
                        height: sheetPosition == .full
                            ? geo.size.height * 0.12
                            : geo.size.height - SheetPosition.peek.height(screenHeight: geo.size.height) + 40
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: sheetPosition)
                    Spacer()
                }

                // Lift Sheet
                LiftSheetView(
                    members: firestoreService.members,
                    submissions: firestoreService.mappedSubmissions,
                    userActivities: firestoreService.userActivities,
                    recentSubmissions: firestoreService.todaysSubmissions,
                    teamId: teamId,
                    onVote: { submissionId, vote in
                        Task {
                            let date = FirestoreService.todayDateString()
                            try? await firestoreService.castVote(
                                teamId: teamId,
                                date: date,
                                submissionId: submissionId,
                                vote: vote
                            )
                        }
                    },
                    onSubmitTap: { showUpload = true },
                    position: $sheetPosition
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            shieldVM.observe(firestoreService)
        }
        .onDisappear {
            shieldVM.stopObserving()
        }
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
        .fullScreenCover(isPresented: $showUpload) {
            UploadProofView()
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(onTeamTap: {})
        .environmentObject(AuthManager())
        .environmentObject(FirestoreService())
}
