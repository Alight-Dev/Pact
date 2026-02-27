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
import SwiftData

// MARK: - FirestoreService

@MainActor
final class FirestoreService: ObservableObject {

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    // Real-time listener handles (retained so we can detach them)
    private var teamListener: ListenerRegistration?
    private var submissionsListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    // Published so views can observe live data
    @Published var currentTeam: [String: Any]?
    @Published var todaysSubmissions: [[String: Any]] = []

    // Published, typed session state for the UI
    @Published var currentTeamId: String?
    @Published var currentTeamName: String?
    @Published var adminTimezone: String?
    @Published var members: [TeamMember] = []

    /// Convenience accessor exposing today's submissions as strongly-typed models.
    var mappedSubmissions: [Submission] {
        todaysSubmissions.compactMap { Submission(dictionary: $0) }
    }

    deinit {
        teamListener?.remove()
        submissionsListener?.remove()
        membersListener?.remove()
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

    // MARK: - Membership & Session

    /// Lightweight snapshot of the user's active team membership.
    struct ActiveMembership {
        let teamId: String
        let teamName: String
        let shieldTier: String
        let currentStreakDays: Int
        let adminTimezone: String
    }

    /// Loads the first active team membership for the current user, if any.
    func loadActiveMembership() async throws -> ActiveMembership? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }

        let membershipsRef = db.collection("users")
            .document(uid)
            .collection("teamMemberships")

        let snapshot = try await membershipsRef
            .whereField("shardStatus", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        let data = document.data()
        let teamId = data["teamId"] as? String ?? document.documentID
        let teamName = data["teamName"] as? String ?? "Your Team"
        let shieldTier = data["shieldTier"] as? String ?? ""
        let currentStreakDays = data["currentStreakDays"] as? Int ?? 0
        let adminTimezone = data["adminTimezone"] as? String
            ?? TimeZone.current.identifier

        return ActiveMembership(
            teamId: teamId,
            teamName: teamName,
            shieldTier: shieldTier,
            currentStreakDays: currentStreakDays,
            adminTimezone: adminTimezone
        )
    }

    /// Starts a full team session: stores IDs, persists to UserDefaults,
    /// and attaches team, members, and today's submissions listeners.
    func startTeamSession(teamId: String, teamName: String, adminTimezone: String) {
        currentTeamId = teamId
        currentTeamName = teamName
        self.adminTimezone = adminTimezone

        UserDefaults.standard.set(teamId, forKey: "app_team_id")
        UserDefaults.standard.set(teamName, forKey: "app_team_name")
        UserDefaults.standard.set(adminTimezone, forKey: "app_team_timezone")

        listenToTeam(teamId: teamId)
        listenToMembers(teamId: teamId)

        let todayDate = Self.todayString(in: adminTimezone)
        listenToTodaysSubmissions(teamId: teamId, date: todayDate)
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
                guard let data = snapshot?.data() else {
                    self?.currentTeam = nil
                    return
                }
                self?.currentTeam = data

                // Keep adminTimezone in sync with the server-side value.
                if let tz = data["adminTimezone"] as? String {
                    self?.adminTimezone = tz
                    UserDefaults.standard.set(tz, forKey: "app_team_timezone")
                }
            }
    }

    /// Attaches a real-time listener to `teams/{teamId}/members`.
    /// Publishes a typed `members` array.
    func listenToMembers(teamId: String) {
        membersListener?.remove()
        membersListener = db.collection("teams").document(teamId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, _ in
                let docs = snapshot?.documents ?? []
                self?.members = docs.compactMap { TeamMember(document: $0) }
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
        membersListener?.remove()
        teamListener = nil
        submissionsListener = nil
        membersListener = nil
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

    // MARK: - Goal Sync → SwiftData

    /// Reads `teams/{teamId}/goals` once and upserts them into the local SwiftData `Activity` store.
    /// This keeps `ActivityListView` / `HomeView` in sync with server-defined goals.
    func syncGoalsToLocalActivities(teamId: String, context: ModelContext) async throws {
        let goalsSnapshot = try await db
            .collection("teams").document(teamId)
            .collection("goals")
            .getDocuments()

        // For now we simply recreate the local cache from scratch.
        let descriptor = FetchDescriptor<Activity>()
        if let current = try? context.fetch(descriptor) {
            for activity in current {
                context.delete(activity)
            }
        }

        for doc in goalsSnapshot.documents {
            let data = doc.data()
            let name = data["name"] as? String ?? "Goal"
            let description = data["description"] as? String ?? ""
            let iconName = data["iconName"] as? String ?? "checkmark.circle"
            let order = data["order"] as? Int ?? 0
            let repeatDays = data["repeatDays"] as? [Int] ?? []
            let isOptional = data["isOptional"] as? Bool ?? false

            let activity = Activity(
                name: name,
                activityDescription: description,
                iconName: iconName,
                order: order,
                repeatDays: repeatDays,
                isOptional: isOptional
            )
            context.insert(activity)
        }
    }

    // MARK: - Helpers

    /// Returns today's date string in `yyyy-MM-dd` for the given timezone identifier.
    private static func todayString(in timezoneIdentifier: String) -> String {
        let tz = TimeZone(identifier: timezoneIdentifier) ?? .current
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = tz
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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

// MARK: - Typed Models

struct TeamMember: Identifiable {
    let id: String
    let displayName: String
    let nickname: String
    let avatarAssetName: String
    let role: String
    let joinedAt: Date?

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        self.id = document.documentID
        self.displayName = data["displayName"] as? String ?? ""
        self.nickname = data["nickname"] as? String ?? ""
        self.avatarAssetName = data["avatarAssetName"] as? String ?? ""
        self.role = data["role"] as? String ?? "member"
        if let ts = data["joinedAt"] as? Timestamp {
            self.joinedAt = ts.dateValue()
        } else {
            self.joinedAt = nil
        }
    }
}

struct Submission: Identifiable {
    let id: String
    let submitterUid: String
    let displayName: String
    let nickname: String
    let avatarAssetName: String
    let activityName: String
    let status: String
    let approvalsReceived: Int
    let approvalsRequired: Int

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["uid"] as? String ?? dictionary["submitterUid"] as? String else {
            return nil
        }
        self.id = id
        self.submitterUid = id
        self.displayName = dictionary["displayName"] as? String ?? ""
        self.nickname = dictionary["nickname"] as? String ?? ""
        self.avatarAssetName = dictionary["avatarAssetName"] as? String ?? ""
        self.activityName = dictionary["activityName"] as? String ?? ""
        self.status = dictionary["status"] as? String ?? "pending"
        self.approvalsReceived = dictionary["approvalsReceived"] as? Int
            ?? dictionary["approvedCount"] as? Int
            ?? 0
        self.approvalsRequired = dictionary["approvalsRequired"] as? Int
            ?? dictionary["eligibleVoterCount"] as? Int
            ?? 0
    }
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

