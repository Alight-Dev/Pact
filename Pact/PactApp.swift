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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    WelcomeView(onGetStarted: {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    })
                }

                if showingSplash {
                    SplashView(onFinished: {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showingSplash = false
                        }
                    })
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
