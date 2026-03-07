//
//  PactApp.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/24/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import os.log
import UIKit

private let deepLinkLog = Logger(subsystem: "cmc.Pact", category: "DeepLink")

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
    @State private var showAppBlocking = false
    @State private var appBlockingGoesToTeamWelcome = false
    @State private var showTeamWelcome = false
    @State private var showForgePact = false
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
        else if showForgePact { forgePact }
        else if showTeamWelcome { teamWelcome }
        else if showAppBlocking { appBlocking }
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
            if isJoinDeepLink(url) {
                DeepLinkManager.shared.setPendingURL(nil)
                if let code = parseInviteCode(from: url) {
                    deepLinkLog.info("Deep link opened: \(url.absoluteString) → code \(code)")
                    pendingJoinCode = code
                    withAnimation {
                        if showHomeScreen {
                            showJoinShieldSheet = true
                        } else if showShieldSelection {
                            showJoinShield = true
                        }
                    }
                } else {
                    deepLinkLog.warning("Join deep link invalid or missing code: \(url.absoluteString)")
                }
            } else {
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .onAppear {
            if let url = DeepLinkManager.shared.consumePendingURL(),
               let code = parseInviteCode(from: url) {
                deepLinkLog.info("Processing pending deep link (cold start): \(url.absoluteString) → code \(code)")
                pendingJoinCode = code
                withAnimation {
                    if showHomeScreen {
                        showJoinShieldSheet = true
                    } else if showShieldSelection {
                        showJoinShield = true
                    }
                }
            }
        }
        .onChange(of: authManager.currentUser) { _, user in
            if user == nil {
                withAnimation {
                    showHomeScreen = false
                    showForgePact = false
                    showJoinShieldActivities = false
                    showActivitiesSetup = false
                    showAppBlocking = false
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
            if let teamId, !teamId.isEmpty {
                // User joined or resumed a team — start the morning lock schedule.
                AppBlockingService.shared.scheduleMorningLock()
            } else {
                // User left a team — cancel the schedule and clear any active lock.
                AppBlockingService.shared.cancelSchedule()
                AppBlockingService.shared.unlock()
            }
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
        // Unlock apps the moment any activity is approved for the current user.
        .onChange(of: firestoreService.mappedSubmissions) { _, submissions in
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let hasApproval = submissions.contains {
                $0.submitterUid == uid &&
                ($0.status == "approved" || $0.status == "auto_approved")
            }
            if hasApproval {
                AppBlockingService.shared.unlock()
            }
        }
        // Re-check on foreground: if the morning lock fired while the app was
        // closed but the user already had an approval today, unlock immediately.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let hasApproval = firestoreService.mappedSubmissions.contains {
                $0.submitterUid == uid &&
                ($0.status == "approved" || $0.status == "auto_approved")
            }
            if hasApproval {
                AppBlockingService.shared.unlock()
            }
        }
    }

    @ViewBuilder
    private var homeScreen: some View {
        HomeScreenView()
            .transition(.opacity)
            .sheet(isPresented: $showJoinShieldSheet, onDismiss: {
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
                    },
                    onJoined: {
                        withAnimation { showJoinShieldSheet = false }
                        pendingJoinCode = ""
                        withAnimation { showForgePact = true }
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
    private var forgePact: some View {
        ForgePactView(onContinue: {
            withAnimation {
                showForgePact = false
                showHomeScreen = true
            }
        })
        .transition(.opacity)
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
                    showForgePact = true
                }
            }
        )
        .transition(.opacity)
    }
    @ViewBuilder
    private var appBlocking: some View {
        AppBlockingSelectionView(
            onContinue: {
                withAnimation {
                    showAppBlocking = false
                    if appBlockingGoesToTeamWelcome {
                        showTeamWelcome = true
                    } else {
                        showHomeScreen = true
                    }
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
                    appBlockingGoesToTeamWelcome = true
                    showAppBlocking = true
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
                    showForgePact = true
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
                    appBlockingGoesToTeamWelcome = false
                    showAppBlocking = true
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
                if let session = await resolveTeamSession() {
                    withAnimation {
                        showSignupDirect = false
                        firestoreService.startTeamSession(
                            teamId: session.teamId,
                            teamName: session.teamName,
                            adminTimezone: session.adminTimezone
                        )
                        showForgePact = true
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
            shouldAutoRoute: { Auth.auth().currentUser != nil },
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
                    if let session = await resolveTeamSession() {
                        withAnimation {
                            firestoreService.startTeamSession(
                                teamId: session.teamId,
                                teamName: session.teamName,
                                adminTimezone: session.adminTimezone
                            )
                            showForgePact = true
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

    private func resolveTeamSession() async -> (teamId: String, teamName: String, adminTimezone: String)? {
        if let m = try? await firestoreService.loadActiveMembership() {
            return (m.teamId, m.teamName, m.adminTimezone)
        }
        if let teamId = UserDefaults.standard.string(forKey: "app_team_id"), !teamId.isEmpty {
            let teamName = UserDefaults.standard.string(forKey: "app_team_name") ?? "Your Team"
            let timezone = UserDefaults.standard.string(forKey: "app_team_timezone") ?? TimeZone.current.identifier
            return (teamId, teamName, timezone)
        }
        return nil
    }
}

