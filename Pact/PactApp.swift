//
//  PactApp.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/24/26.
//

import SwiftUI
import SwiftData

@main
struct PactApp: App {
    @State private var showOnboarding = false
    @State private var showShieldSelection = false
    @State private var showHomeScreen = false

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
            if showHomeScreen {
                HomeScreenView()
            } else if showShieldSelection {
                OnboardingCreateOrJoinSheildView(
                    onCreateShield: {
                        withAnimation {
                            showShieldSelection = false
                            showHomeScreen = true
                        }
                    },
                    onJoinShield: {
                        withAnimation {
                            showShieldSelection = false
                            showHomeScreen = true
                        }
                    },
                    onNoAccount: {
                        withAnimation {
                            showShieldSelection = false
                            showHomeScreen = true
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
            } else {
                SplashView(onFinished: {
                    withAnimation {
                        showOnboarding = true
                    }
                })
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
