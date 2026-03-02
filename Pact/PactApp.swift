//
//  PactApp.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/24/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn

@main
struct PactApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var firestoreService = FirestoreService()
    @State private var showOnboarding = false
    @State private var showSignupDirect = false
    @State private var showShieldSelection = false
    @State private var showJoinShield = false
    @State private var showHomeScreen = false
    /// Invite code passed in via a pact://join/{code} deep-link when auto-join fails.
    @State private var pendingJoinCode: String = ""
    @State private var showTeamName = false
    @State private var showActivitiesSetup = false
    @State private var showPactLaunch = false
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
            Group {
                if showHomeScreen {
                    HomeScreenView()
                        .transition(.opacity)
                        // Deep link received while already on home screen → sheet
                        .sheet(isPresented: $showJoinShieldSheet, onDismiss: {
                            pendingJoinCode = ""
                        }) {
                            JoinShieldView(
                                onBack: {
                                    withAnimation { showJoinShieldSheet = false }
                                    pendingJoinCode = ""
                                },
                                onJoined: {
                                    // User joined a second team; listeners are updated
                                    // via startTeamSession inside JoinShieldView.
                                    withAnimation { showJoinShieldSheet = false }
                                    pendingJoinCode = ""
                                },
                                initialCode: pendingJoinCode
                            )
                        }
                        .alert("Already in a Team", isPresented: $showAlreadyInTeamAlert) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("You're already in a team. Leave your current team first to join a new one.")
                        }
                } else if showPactLaunch {
                    PactLaunchView(
                        onFinished: {
                            withAnimation {
                                showPactLaunch = false
                                showHomeScreen = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showActivitiesSetup {
                    ActivityListView(
                        teamName: pendingTeamName,
                        onContinue: {
                            withAnimation {
                                showActivitiesSetup = false
                                showPactLaunch = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showTeamName {
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
                } else if showJoinShield {
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
                                showHomeScreen = true
                            }
                        },
                        initialCode: pendingJoinCode
                    )
                    .transition(.opacity)
                } else if showShieldSelection {
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
                        },
                        onSkip: {
                            withAnimation {
                                showShieldSelection = false
                                showHomeScreen = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showOnboarding {
                    OnboardingFlowView(onFinished: {
                        withAnimation {
                            showOnboarding = false
                            // If a deep link arrived during onboarding, go straight to join.
                            if !pendingJoinCode.isEmpty {
                                showJoinShield = true
                            } else {
                                showShieldSelection = true
                            }
                        }
                    })
                    .transition(.opacity)
                } else if showSignupDirect {
                    OnboardingSignupView(
                        onBack: {
                            withAnimation {
                                showSignupDirect = false
                            }
                        },
                        onContinue: {
                            // Async — OnboardingSignupView's isLoading spinner stays
                            // active until this resolves, so the user sees no flash.
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
                } else {
                    SplashView(
                        onFinished: {
                            // Async — SplashView shows spinner while this runs.
                            // No intermediate screen is shown before we know where to route.
                            if authManager.currentUser != nil {
                                // Already signed in: check for an existing team first.
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
                                // Not signed in: start onboarding.
                                withAnimation { showOnboarding = true }
                            }
                        },
                        onSkipToSignup: {
                            withAnimation {
                                showSignupDirect = true
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .environmentObject(authManager)
            .environmentObject(firestoreService)
            .onOpenURL { url in
                // Handle pact://join/{code} deep links.
                // • Already on HomeScreen → sheet over the current view.
                // • Anywhere else → set showJoinShield; pendingJoinCode is preserved
                //   through onboarding/sign-in and consumed by routeAfterAuth().
                if url.scheme == "pact", url.host == "join",
                   let code = url.pathComponents.last, code.count == 6 {
                    pendingJoinCode = code
                    withAnimation {
                        if showHomeScreen {
                            if firestoreService.currentTeamId != nil {
                                // User is already in a team — cannot join another
                                pendingJoinCode = ""
                                showAlreadyInTeamAlert = true
                            } else {
                                showJoinShieldSheet = true
                            }
                        } else {
                            showJoinShield = true
                        }
                    }
                } else {
                    GIDSignIn.sharedInstance.handle(url)
                }
            }
            .onChange(of: authManager.currentUser) { _, user in
                if user == nil {
                    withAnimation {
                        showHomeScreen = false
                        showActivitiesSetup = false
                        showTeamName = false
                        showPactLaunch = false
                        showShieldSelection = false
                        showJoinShield = false
                        showOnboarding = false
                        showSignupDirect = false
                    }
                    firestoreService.stopListeners()
                } else {
                    // Refresh FCM token on sign-in
                    Task {
                        if let token = try? await Messaging.messaging().token() {
                            await firestoreService.updateFCMToken(token)
                        }
                    }
                }
            }
            // When clearTeamSession() sets currentTeamId to nil while the user
            // is on the home screen (e.g. after leaving a team), route them to
            // the Create/Join shield screen so they can join or create a new team.
            .onChange(of: firestoreService.currentTeamId) { _, teamId in
                if teamId == nil && showHomeScreen {
                    withAnimation {
                        showHomeScreen = false
                        showShieldSelection = true
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

