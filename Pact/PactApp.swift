//
//  PactApp.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/24/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main
struct PactApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var firestoreService = FirestoreService()
    @StateObject private var notificationRouter = NotificationRouter()
    @State private var showOnboarding = false
    @State private var showSignupDirect = false
    @State private var showShieldSelection = false
    @State private var showJoinShield = false
    @State private var showJoinShieldActivities = false
    @State private var showHomeScreen = false
    /// Invite code passed in via a pact://join/{code} deep-link when auto-join fails.
    @State private var pendingJoinCode: String = ""
    @State private var showTeamName = false
    @State private var showActivitiesSetup = false
    @State private var showCreatorActivitySelection = false
    @State private var showTeamWelcome = false
    @State private var welcomeInviteCode = ""
    @State private var pendingTeamName = ""
    /// Set when a pact://join/{code} deep link arrives while the user is on HomeScreenView.
    /// Drives a .sheet presentation of JoinShieldView over the home screen.
    @State private var showJoinShieldSheet = false
    /// Set when a deep link arrives but the user is already in a team.
    @State private var showAlreadyInTeamAlert = false

    init() {
        FirebaseApp.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Activity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed without a migration plan (common during development).
            // Destroy the old store files and recreate from scratch.
            let storeURL = modelConfiguration.url
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = URL(fileURLWithPath: storeURL.path + suffix)
                try? FileManager.default.removeItem(at: fileURL)
            }
            do {
                let freshConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [freshConfig])
            } catch {
                fatalError("Could not create ModelContainer after store reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            rootContent
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var activeScreen: some View {
        if showHomeScreen { homeScreen }
        else if showTeamWelcome { teamWelcome }
        else if showActivitiesSetup { activitiesSetup }
        else if showTeamName { teamName }
        else if showJoinShieldActivities { joinShieldActivities }
        else if showJoinShield { joinShield }
        else if showShieldSelection { shieldSelection }
        else if showOnboarding { onboarding }
        else if showSignupDirect { signupDirect }
        else { splash }
    }

    @ViewBuilder
    private var rootContent: some View {
        activeScreen
        .environmentObject(authManager)
        .environmentObject(firestoreService)
        .environmentObject(notificationRouter)
        .onOpenURL { url in
            // Handle pact://join/{code} deep links.
            // Only show join UI when user is already signed in and has completed onboarding
            // (on home screen or shield selection). Otherwise only store the code for later.
            if url.scheme == "pact", url.host == "join",
               let code = url.pathComponents.last, code.count == 6 {
                pendingJoinCode = code
                withAnimation {
                    if showHomeScreen {
                        // Always show join sheet with code; if user is in a team,
                        // JoinShieldView will show a warning when they tap Join Shield.
                        showJoinShieldSheet = true
                    } else if showShieldSelection {
                        showJoinShield = true
                    }
                    // Else: Splash, onboarding, signup, etc. — only pendingJoinCode is set;
                    // existing flows will route to join after sign-in/onboarding.
                }
            } else {
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .onChange(of: authManager.currentUser) { _, user in
            if user == nil {
                withAnimation {
                    showHomeScreen = false
                    showJoinShieldActivities = false
                    showActivitiesSetup = false
                    showTeamName = false
                    showTeamWelcome = false
                    welcomeInviteCode = ""
                    showShieldSelection = false
                    showJoinShield = false
                    showOnboarding = false
                    showSignupDirect = false
                }
                firestoreService.stopListeners()
            }
        }
        // When clearTeamSession() sets currentTeamId to nil while the user
        // is on the home screen (e.g. after leaving a team), route them to
        // the Create/Join shield screen so they can join or create a new team.
        .onChange(of: firestoreService.currentTeamId) { _, teamId in
            // Skip mid-join: if the join sheet is open, the leave→join sequence
            // is in progress — don't route away. onDismiss handles the fallback.
            if teamId == nil && showHomeScreen && !showJoinShieldSheet {
                withAnimation {
                    showHomeScreen = false
                    showShieldSelection = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fcmTokenRefreshed)) { note in
            if let token = note.userInfo?["token"] as? String {
                Task { await firestoreService.updateFCMToken(token) }
            }
        }
    }

    @ViewBuilder
    private var homeScreen: some View {
        HomeScreenView()
            .transition(.opacity)
            .sheet(isPresented: $showJoinShieldSheet, onDismiss: {
                pendingJoinCode = ""
                if firestoreService.currentTeamId == nil {
                    withAnimation {
                        showHomeScreen = false
                        showShieldSelection = true
                    }
                }
            }) {
                JoinShieldView(
                    onBack: {
                        withAnimation { showJoinShieldSheet = false }
                        pendingJoinCode = ""
                    },
                    onJoined: {
                        withAnimation { showJoinShieldSheet = false }
                        pendingJoinCode = ""
                        withAnimation { showHomeScreen = true }
                    },
                    initialCode: pendingJoinCode
                )
            }
            .alert("Already in a Team", isPresented: $showAlreadyInTeamAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You're already in a team. Leave your current team first to join a new one.")
            }
    }

    @ViewBuilder
    private var teamWelcome: some View {
        TeamWelcomeView(
            teamName: pendingTeamName,
            inviteCode: welcomeInviteCode,
            onFinished: {
                withAnimation {
                    showTeamWelcome = false
                    welcomeInviteCode = ""
                    showHomeScreen = true
                }
            }
        )
        .transition(.opacity)
    }
    @ViewBuilder
    private var activitiesSetup: some View {
        ActivityListView(
            teamName: pendingTeamName,
            onContinue: { inviteCode in
                withAnimation {
                    showActivitiesSetup = false
                    welcomeInviteCode = inviteCode
                    showTeamWelcome = true
                }
            }
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var teamName: some View {
        OnboardingTeamNameView(
            onBack: {
                withAnimation {
                    showTeamName = false
                    showShieldSelection = true
                }
            },
            onContinue: { name in
                pendingTeamName = name
                withAnimation {
                    showTeamName = false
                    showActivitiesSetup = true
                }
            }
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var joinShieldActivities: some View {
        JoinShieldActivitiesView(
            onContinue: {
                withAnimation {
                    showJoinShieldActivities = false
                    showHomeScreen = true
                }
            }
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var joinShield: some View {
        JoinShieldView(
            onBack: {
                withAnimation {
                    showJoinShield = false
                    pendingJoinCode = ""
                    showShieldSelection = true
                }
            },
            onJoined: {
                withAnimation {
                    showJoinShield = false
                    pendingJoinCode = ""
                    showJoinShieldActivities = true
                }
            },
            initialCode: pendingJoinCode
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var shieldSelection: some View {
        OnboardingCreateOrJoinShieldView(
            onCreateShield: {
                withAnimation {
                    showShieldSelection = false
                    showTeamName = true
                }
            },
            onJoinShield: {
                withAnimation {
                    showShieldSelection = false
                    showJoinShield = true
                }
            }
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var onboarding: some View {
        OnboardingFlowView(onFinished: {
            withAnimation {
                showOnboarding = false
                if !pendingJoinCode.isEmpty {
                    showJoinShield = true
                } else {
                    showShieldSelection = true
                }
            }
        })
        .transition(.opacity)
    }

    @ViewBuilder
    private var signupDirect: some View {
        OnboardingSignupView(
            onBack: {
                withAnimation {
                    showSignupDirect = false
                }
            },
            onContinue: {
                let completed: Bool
                do {
                    completed = try await firestoreService.hasCompletedOnboarding()
                } catch {
                    completed = false
                }
                if !completed {
                    withAnimation {
                        showSignupDirect = false
                        showOnboarding = true
                    }
                    return
                }
                if !pendingJoinCode.isEmpty {
                    withAnimation {
                        showSignupDirect = false
                        showJoinShield = true
                    }
                    return
                }
                if let membership = try? await firestoreService.loadActiveMembership() {
                    withAnimation {
                        showSignupDirect = false
                        firestoreService.startTeamSession(
                            teamId: membership.teamId,
                            teamName: membership.teamName,
                            adminTimezone: membership.adminTimezone
                        )
                        showHomeScreen = true
                    }
                } else {
                    withAnimation {
                        showSignupDirect = false
                        showShieldSelection = true
                    }
                }
            }
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var splash: some View {
        SplashView(
            shouldAutoRoute: { authManager.currentUser != nil },
            onFinished: {
                if authManager.currentUser != nil {
                    let completed: Bool
                    do {
                        completed = try await firestoreService.hasCompletedOnboarding()
                    } catch {
                        completed = false
                    }
                    if !completed {
                        withAnimation { showOnboarding = true }
                        return
                    }
                    if !pendingJoinCode.isEmpty {
                        withAnimation { showJoinShield = true }
                        return
                    }
                    if let membership = try? await firestoreService.loadActiveMembership() {
                        withAnimation {
                            firestoreService.startTeamSession(
                                teamId: membership.teamId,
                                teamName: membership.teamName,
                                adminTimezone: membership.adminTimezone
                            )
                            showHomeScreen = true
                        }
                    } else {
                        withAnimation { showShieldSelection = true }
                    }
                } else {
                    withAnimation { showSignupDirect = true }
                }
            }
        )
        .transition(.opacity)
    }
}

