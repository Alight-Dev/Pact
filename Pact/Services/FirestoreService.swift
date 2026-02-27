//
//  FirestoreService.swift
//  Pact
//
//  NOTE: This file requires FirebaseFunctions to be linked to the Pact target.
//  In Xcode: Target → General → Frameworks, Libraries, and Embedded Content → +
//  → search "FirebaseFunctions" → Add.
//  (It is part of the firebase-ios-sdk package already in the project.)
//  If you see 'Missing required module "FirebaseMessagingInterop"', also add the
//  FirebaseMessaging product to the Pact target (SPM dependency).
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging

// MARK: - FirestoreService

@MainActor
final class FirestoreService: ObservableObject {

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    // Real-time listener handles (retained so we can detach them)
    private var teamListener: ListenerRegistration?
    private var submissionsListener: ListenerRegistration?

    // Published so views can observe live data
    @Published var currentTeam: [String: Any]?
    @Published var todaysSubmissions: [[String: Any]] = []

    deinit {
        teamListener?.remove()
        submissionsListener?.remove()
    }

    // MARK: - User Profile

    /// Writes the full user profile to `users/{uid}`.
    /// Called at the end of onboarding (profileSetup.onContinue).
    func saveUserProfile(
        uid: String,
        displayName: String,
        email: String?,
        isAnonymous: Bool,
        nickname: String,
        avatarID: Int,
        avatarAssetName: String,
        gender: String,
        ageRange: String,
        dailyScreenTime: String,
        smartphoneYears: Int,
        appCategories: [String]
    ) async throws {
        var data: [String: Any] = [
            "uid": uid,
            "displayName": displayName,
            "nickname": nickname,
            "avatarID": avatarID,
            "avatarAssetName": avatarAssetName,
            "fcmTokens": [],
            "subscriptionTier": "free",
            "isAnonymous": isAnonymous,
            "updatedAt": FieldValue.serverTimestamp(),
            "lastUnlockedAt": NSNull(),
            "gender": gender,
            "ageRange": ageRange,
            "dailyScreenTime": dailyScreenTime,
            "smartphoneYears": smartphoneYears,
            "appCategories": appCategories,
        ]
        if let email { data["email"] = email }

        // merge: true — safe to call again on re-login without wiping existing fields
        try await db.collection("users").document(uid).setData(data, merge: true)

        // Write createdAt only on first save (setData with merge won't overwrite it)
        try await db.collection("users").document(uid).updateData([
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - FCM Token

    /// Appends the FCM token to the user's `fcmTokens` array.
    /// Call this after sign-in and on each app launch.
    func updateFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid)
            .updateData(["fcmTokens": FieldValue.arrayUnion([token])])
    }

    // MARK: - Team Creation (CF-8)

    struct CreateTeamResult {
        let teamId: String
        let inviteCode: String
    }

    /// Calls the `createTeam` Cloud Function.
    /// Returns the new team ID and the 6-digit invite code.
    func createTeam(name: String, activities: [ActivityPayload], timezone: String) async throws -> CreateTeamResult {
        let callable = functions.httpsCallable("createTeam")

        let activityData: [[String: Any]] = activities.map { a in
            [
                "name": a.name,
                "description": a.description,
                "iconName": a.iconName,
                "repeatDays": a.repeatDays,
                "isOptional": a.isOptional,
                "order": a.order,
            ]
        }

        let result = try await callable.call([
            "teamName": name,
            "activities": activityData,
            "adminTimezone": timezone,
        ])

        guard
            let data = result.data as? [String: Any],
            let teamId = data["teamId"] as? String,
            let inviteCode = data["inviteCode"] as? String
        else { throw FirestoreServiceError.invalidResponse }

        return CreateTeamResult(teamId: teamId, inviteCode: inviteCode)
    }

    // MARK: - Team Join (CF-7)

    struct JoinTeamResult {
        let teamId: String
        let teamName: String
    }

    /// Calls the `joinTeam` Cloud Function with the 6-digit invite code.
    func joinTeam(inviteCode: String) async throws -> JoinTeamResult {
        let callable = functions.httpsCallable("joinTeam")
        let result = try await callable.call(["inviteCode": inviteCode])

        guard
            let data = result.data as? [String: Any],
            let teamId = data["teamId"] as? String,
            let teamName = data["teamName"] as? String
        else { throw FirestoreServiceError.invalidResponse }

        return JoinTeamResult(teamId: teamId, teamName: teamName)
    }

    // MARK: - Forge Pact

    /// Writes a forgePactAgreement document for the current user.
    /// CF-3 activates the goal when all members have agreed.
    func forgePact(teamId: String, goalId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw FirestoreServiceError.notAuthenticated }

        let userSnap = try await db.collection("users").document(uid).getDocument()
        let userData = userSnap.data() ?? [:]

        let data: [String: Any] = [
            "userId": uid,
            "displayName": userData["displayName"] as? String ?? "",
            "nickname": userData["nickname"] as? String ?? "",
            "agreedAt": FieldValue.serverTimestamp(),
        ]
        try await db
            .collection("teams").document(teamId)
            .collection("goals").document(goalId)
            .collection("forgePactAgreements").document(uid)
            .setData(data)
    }

    // MARK: - Real-Time Listeners

    /// Attaches a real-time listener to `teams/{teamId}`.
    /// Publishes updates to `currentTeam`.
    func listenToTeam(teamId: String) {
        teamListener?.remove()
        teamListener = db.collection("teams").document(teamId)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.currentTeam = snapshot?.data()
            }
    }

    /// Attaches a real-time listener to today's submissions subcollection.
    /// Publishes updates to `todaysSubmissions`.
    func listenToTodaysSubmissions(teamId: String, date: String) {
        submissionsListener?.remove()
        submissionsListener = db
            .collection("teams").document(teamId)
            .collection("dailyInstances").document(date)
            .collection("submissions")
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.todaysSubmissions = snapshot?.documents.map { $0.data() } ?? []
            }
    }

    func stopListeners() {
        teamListener?.remove()
        submissionsListener?.remove()
        teamListener = nil
        submissionsListener = nil
    }

    // MARK: - Voting

    /// Writes a vote document to `votes/{voterId}`.
    /// Security rules enforce no double-voting and no self-approval.
    func castVote(teamId: String, date: String, submitterUid: String, vote: String) async throws {
        guard let voterId = Auth.auth().currentUser?.uid else { throw FirestoreServiceError.notAuthenticated }

        let userSnap = try await db.collection("users").document(voterId).getDocument()
        let nickname = userSnap.data()?["nickname"] as? String ?? ""

        let data: [String: Any] = [
            "voterId": voterId,
            "vote": vote, // "approve" or "reject"
            "votedAt": FieldValue.serverTimestamp(),
            "voterNickname": nickname,
        ]
        try await db
            .collection("teams").document(teamId)
            .collection("dailyInstances").document(date)
            .collection("submissions").document(submitterUid)
            .collection("votes").document(voterId)
            .setData(data)
    }
}

// MARK: - ActivityPayload

/// Lightweight value type used to pass Activity data to FirestoreService
/// without importing SwiftData into the service layer.
struct ActivityPayload {
    let name: String
    let description: String
    let iconName: String
    let repeatDays: [Int]
    let isOptional: Bool
    let order: Int
}

// MARK: - Errors

enum FirestoreServiceError: LocalizedError {
    case invalidResponse
    case notAuthenticated
    case inviteNotFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:   return "Received an unexpected response from the server."
        case .notAuthenticated:  return "You must be signed in to perform this action."
        case .inviteNotFound:    return "Invite code not found or expired."
        }
    }
}

