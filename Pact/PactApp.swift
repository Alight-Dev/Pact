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
    @StateObject private var authManager = AuthManager()
    @State private var showOnboarding = false
    @State private var showSignupDirect = false
    @State private var showShieldSelection = false
    @State private var showJoinShield = false
    @State private var showHomeScreen = false
    @State private var showActivitiesSetup = false
    @State private var showPactLaunch = false

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
                        onContinue: {
                            withAnimation {
                                showActivitiesSetup = false
                                showPactLaunch = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showJoinShield {
                    JoinShieldView(
                        onBack: {
                            withAnimation {
                                showJoinShield = false
                                showShieldSelection = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showShieldSelection {
                    OnboardingCreateOrJoinShieldView(
                        onCreateShield: {
                            withAnimation {
                                showShieldSelection = false
                                showActivitiesSetup = true
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
                } else if showOnboarding {
                    OnboardingFlowView(onFinished: {
                        withAnimation {
                            showOnboarding = false
                            showShieldSelection = true
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
                            withAnimation {
                                showSignupDirect = false
                                showShieldSelection = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    SplashView(
                        onFinished: {
                            withAnimation {
                                if authManager.currentUser != nil {
                                    // Already signed in — skip onboarding
                                    showShieldSelection = true
                                } else {
                                    showOnboarding = true
                                }
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onChange(of: authManager.currentUser) { _, user in
                if user == nil {
                    withAnimation {
                        showHomeScreen = false
                        showActivitiesSetup = false
                        showPactLaunch = false
                        showShieldSelection = false
                        showJoinShield = false
                        showOnboarding = false
                        showSignupDirect = false
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

