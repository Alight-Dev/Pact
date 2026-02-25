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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if showHomeScreen {
                HomeScreenView()
            } else {
                SplashView(onFinished: {
                    withAnimation {
                        showHomeScreen = true
                    }
                })
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
