//
//  AuthManager.swift
//  Pact
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        currentUser = authResult.user
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        currentUser = nil
    }

    /// Deletes the Firebase Auth account, clears all local app data, and signs out.
    /// After this call `currentUser` becomes nil which triggers PactApp to reset to splash.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        GIDSignIn.sharedInstance.signOut()
        // Clear all persisted app data so onboarding starts fresh.
        let keys = ["app_nickname", "app_avatar", "app_avatar_asset", "app_team_id", "app_team_name"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        currentUser = nil
    }
}

enum AuthError: LocalizedError {
    case missingClientID
    case noViewController
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Firebase client ID not found. Check GoogleService-Info.plist."
        case .noViewController:
            return "Could not find a view controller to present sign-in."
        case .missingToken:
            return "Google ID token was missing from the sign-in result."
        }
    }
}
