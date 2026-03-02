//
//  AuthManager.swift
//  Pact
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
//    private var appleSignInHandler: AppleSignInHandler?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

//    func signInWithApple() async throws {
//        let nonce = randomNonceString()
//        currentNonce = nonce
//        
//        let appleIDProvider = ASAuthorizationAppleIDProvider()
//        let request = appleIDProvider.createRequest()
//        request.requestedScopes = [.fullName, .email]
//        request.nonce = sha256(nonce)
//        
//        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
//        
//        // Use a delegate to handle the authorization
//        let delegate = try await SignInWithAppleDelegate.signIn()
//        
//        guard let appleIDCredential = delegate.credential as? ASAuthorizationAppleIDCredential,
//              let appleIDToken = appleIDCredential.identityToken,
//              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
//            throw AuthError.missingToken
//        }
//        
//        let credential = OAuthProvider.appleCredential(
//            withIDToken: idTokenString,
//            rawNonce: nonce,
//            fullName: appleIDCredential.fullName
//        )
//        
//        let authResult = try await Auth.auth().signIn(with: credential)
//        currentUser = authResult.user
//    }
    
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

//    func signInWithApple() async throws {
//        let nonce = randomNonceString()
//        currentNonce = nonce
//
//        let request = ASAuthorizationAppleIDProvider().createRequest()
//        request.requestedScopes = [.fullName, .email]
//        request.nonce = sha256(nonce)
//
//        let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
//            let handler = AppleSignInHandler(continuation: continuation)
//            appleSignInHandler = handler
//            let controller = ASAuthorizationController(authorizationRequests: [request])
//            controller.delegate = handler
//            controller.presentationContextProvider = handler
//            controller.performRequests()
//        }
//        appleSignInHandler = nil
//
//        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
//              let tokenData = appleCredential.identityToken,
//              let idTokenString = String(data: tokenData, encoding: .utf8),
//              let rawNonce = currentNonce else {
//            throw AuthError.missingAppleToken
//        }
//
//        let firebaseCredential = OAuthProvider.appleCredential(
//            withIDToken: idTokenString,
//            rawNonce: rawNonce,
//            fullName: appleCredential.fullName
//        )
//
//        let authResult = try await Auth.auth().signIn(with: firebaseCredential)
//
//        // Apple only returns the full name on the very first sign-in.
//        // If available and the Firebase user has no display name yet, set it now.
//        if let nameComponents = appleCredential.fullName {
//            let fullName = [nameComponents.givenName, nameComponents.familyName]
//                .compactMap { $0 }
//                .filter { !$0.isEmpty }
//                .joined(separator: " ")
//
//            if !fullName.isEmpty && (authResult.user.displayName?.isEmpty ?? true) {
//                let changeRequest = authResult.user.createProfileChangeRequest()
//                changeRequest.displayName = fullName
//                try await changeRequest.commitChanges()
//            }
//        }
//
//        currentUser = Auth.auth().currentUser
//    }

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

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Apple Sign-In Delegate Bridge

//private class AppleSignInHandler: NSObject,
//    ASAuthorizationControllerDelegate,
//    ASAuthorizationControllerPresentationContextProviding {
//
//    private let continuation: CheckedContinuation<ASAuthorization, Error>
//
//    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
//        self.continuation = continuation
//    }
//
//    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
//        UIApplication.shared.connectedScenes
//            .compactMap { $0 as? UIWindowScene }
//            .flatMap { $0.windows }
//            .first { $0.isKeyWindow } ?? UIWindow()
//    }
//
//    func authorizationController(controller: ASAuthorizationController,
//                                 didCompleteWithAuthorization authorization: ASAuthorization) {
//        continuation.resume(returning: authorization)
//    }
//
//    func authorizationController(controller: ASAuthorizationController,
//                                 didCompleteWithError error: Error) {
//        continuation.resume(throwing: error)
//    }
//}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingClientID
    case noViewController
    case missingToken
    case missingAppleToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Firebase client ID not found. Check GoogleService-Info.plist."
        case .noViewController:
            return "Could not find a view controller to present sign-in."
        case .missingToken:
            return "Google ID token was missing from the sign-in result."
        case .missingAppleToken:
            return "Apple identity token was missing from the sign-in result."
        }
    }
}

