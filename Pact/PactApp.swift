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
                } else if showJoinShield {
                    JoinShieldView(
                        onBack: {
                            withAnimation {
                                showJoinShield = false
                                showShieldSelection = true
                            }
                        }
                    )
                } else if showShieldSelection {
                    OnboardingCreateOrJoinShieldView(
                        onCreateShield: {
                            withAnimation {
                                showShieldSelection = false
                                showHomeScreen = true
                            }
                        },
                        onJoinShield: {
                            withAnimation {
                                showShieldSelection = false
                                showJoinShield = true
                            }
                        }
                    )
                } else if showOnboarding {
                    OnboardingFlowView(onFinished: {
                        withAnimation {
                            showOnboarding = false
                            showShieldSelection = true
                        }
                    })
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
                }
            }
            .environmentObject(authManager)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

