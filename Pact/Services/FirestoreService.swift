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
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import FirebaseStorage
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
    private var activitiesListener: ListenerRegistration?

    // Published so views can observe live data
    @Published var currentTeam: [String: Any]?
    @Published var todaysSubmissions: [[String: Any]] = []

    /// Submissions the current user has voted on this session (by submission document id).
    /// Set synchronously in `TeamView.handleVote` before the async Firestore
    /// write, so it's available immediately on the next `.onAppear` call even
    /// if the write hasn't completed yet.  Cleared on `clearTeamSession()`.
    var votedSubmissionIds: Set<String> = []

    // Published, typed session state for the UI
    @Published var currentTeamId: String?
    @Published var currentTeamName: String?
    @Published var adminTimezone: String?
    @Published var members: [TeamMember] = []
    @Published var teamActivities: [TeamActivity] = []
    @Published var optedInActivityIds: Set<String> = []

    /// Activities filtered to only those the current user is opted into.
    /// Returns all activities when optedInActivityIds is empty (e.g. admin / creator).
    var userActivities: [TeamActivity] {
        guard !optedInActivityIds.isEmpty else { return teamActivities }
        return teamActivities.filter { optedInActivityIds.contains($0.id) }
    }

    /// Activity names the current user is opted into (for filtering submissions).
    var userActivityNames: Set<String> {
        Set(userActivities.map(\.name))
    }

    /// Convenience accessor exposing today's submissions as strongly-typed models.
    var mappedSubmissions: [Submission] {
        todaysSubmissions.compactMap { Submission(dictionary: $0) }
    }

    deinit {
        teamListener?.remove()
        submissionsListener?.remove()
        membersListener?.remove()
        activitiesListener?.remove()
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
            "onboardingCompleted": true,
        ]
        if let email { data["email"] = email }

        // merge: true — safe to call again on re-login without wiping existing fields
        try await db.collection("users").document(uid).setData(data, merge: true)

        // Write createdAt only on first save (setData with merge won't overwrite it)
        try await db.collection("users").document(uid).updateData([
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    /// Returns whether the current user has completed onboarding (has a profile with nickname/avatar).
    /// Used to skip onboarding for existing accounts and show it for brand-new accounts.
    func hasCompletedOnboarding() async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let snap = try await db.collection("users").document(uid).getDocument()
        guard let data = snap.data() else { return false }
        if data["onboardingCompleted"] as? Bool == true { return true }
        if (data["nickname"] as? String)?.isEmpty == false { return true }
        return false
    }

    // MARK: - FCM Token

    /// Appends the FCM token to the user's `fcmTokens` array.
    /// Also keeps every active member doc's `fcmToken` field in sync so Cloud
    /// Functions always have a fresh token, regardless of whether currentTeamId
    /// has been populated yet (e.g. cold-launch race where the token fires before
    /// startTeamSession() is called).
    func updateFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid)
            .updateData(["fcmTokens": FieldValue.arrayUnion([token])])

        // Query all active memberships directly — don't rely on currentTeamId
        // being set yet. Handles the cold-start timing gap.
        let membershipsSnap = try? await db
            .collection("users").document(uid)
            .collection("teamMemberships")
            .whereField("shardStatus", isEqualTo: "active")
            .getDocuments()
        for doc in membershipsSnap?.documents ?? [] {
            let teamId = doc.documentID
            try? await db.collection("teams").document(teamId)
                .collection("members").document(uid)
                .updateData(["fcmToken": token])
        }
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
        listenToActivities(teamId: teamId)
        Task { await loadOptedInActivityIds(teamId: teamId) }

        let todayDate = Self.todayString(in: adminTimezone)
        listenToTodaysSubmissions(teamId: teamId, date: todayDate)

        // Eagerly write the latest FCM token to the member doc on every session
        // start. Fixes the case where the token was null because it arrived before
        // this session was established (cold-launch race condition).
        Task {
            if let token = try? await Messaging.messaging().token() {
                await updateFCMToken(token)
            }
        }
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

    // MARK: - Team Leave (CF-9)

    /// Calls the `leaveTeam` Cloud Function.
    /// Pass `newAdminUid` when the caller is the admin and other members remain.
    /// Returns `true` if the team was fully dissolved (caller was last member),
    /// Calls the `updateOptedInActivities` Cloud Function to save selected
    /// activity IDs on the member's document after joining a team.
    func updateOptedInActivities(teamId: String, activityIds: [String]) async throws {
        let callable = functions.httpsCallable("updateOptedInActivities")
        let _ = try await callable.call([
            "teamId": teamId,
            "activityIds": activityIds
        ])
        optedInActivityIds = Set(activityIds)
    }

    /// Fetches the current user's `optedInActivityIds` from their member document
    /// and updates the published property.
    func loadOptedInActivityIds(teamId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("teams").document(teamId)
                .collection("members").document(uid).getDocument()
            let ids = (snap.data()?["optedInActivityIds"] as? [String]) ?? []
            optedInActivityIds = Set(ids)
        } catch {
            optedInActivityIds = []
        }
    }

    /// `false` if other members remain.
    /// After this returns, call `clearTeamSession()` to wipe local state.
    @discardableResult
    func leaveTeam(teamId: String, newAdminUid: String? = nil) async throws -> Bool {
        let callable = functions.httpsCallable("leaveTeam")
        var params: [String: Any] = ["teamId": teamId]
        if let uid = newAdminUid { params["newAdminUid"] = uid }
        let result = try await callable.call(params)
        let data = result.data as? [String: Any]
        return data?["dissolved"] as? Bool ?? false
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
    /// Publishes updates to `todaysSubmissions`. Each document's ID is merged in as "submissionId" for per-activity submission identity.
    func listenToTodaysSubmissions(teamId: String, date: String) {
        submissionsListener?.remove()
        submissionsListener = db
            .collection("teams").document(teamId)
            .collection("dailyInstances").document(date)
            .collection("submissions")
            .addSnapshotListener { [weak self] snapshot, _ in
                let docs = snapshot?.documents ?? []
                self?.todaysSubmissions = docs.map { doc in
                    doc.data().merging(["submissionId": doc.documentID]) { _, new in new }
                }
            }
    }

    /// Attaches a real-time listener to `teams/{teamId}/goals`, ordered by `order`.
    /// Publishes a typed `teamActivities` array used by UploadProofView.
    func listenToActivities(teamId: String) {
        activitiesListener?.remove()
        activitiesListener = db.collection("teams").document(teamId)
            .collection("goals")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, _ in
                let docs = snapshot?.documents ?? []
                self?.teamActivities = docs.compactMap { TeamActivity(document: $0) }
            }
    }

    func stopListeners() {
        teamListener?.remove()
        submissionsListener?.remove()
        membersListener?.remove()
        activitiesListener?.remove()
        teamListener = nil
        submissionsListener = nil
        membersListener = nil
        activitiesListener = nil
        teamActivities = []
    }

    /// Stops all real-time listeners AND clears every team-related @Published
    /// property and UserDefaults key. Call this after leaving a team (without
    /// signing out) so the app can route to the Create/Join screen cleanly.
    func clearTeamSession() {
        stopListeners()
        currentTeamId     = nil
        currentTeamName   = nil
        adminTimezone     = nil
        currentTeam       = nil
        members           = []
        todaysSubmissions = []
        votedSubmissionIds.removeAll()
        optedInActivityIds = []
        let keys = ["app_team_id", "app_team_name", "app_team_timezone", "app_invite_code"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - Voting

    /// Writes a vote document to `votes/{voterId}`.
    /// Security rules enforce no double-voting and no self-approval.
    ///
    /// Also performs a client-side approval check so the UI updates
    /// immediately even when the `onVoteCast` Cloud Function is not deployed.
    /// Both paths are idempotent — they check `status == "pending"` first, so
    /// whichever completes first wins and the other becomes a no-op.
    func castVote(teamId: String, date: String, submissionId: String, vote: String) async throws {
        guard let voterId = Auth.auth().currentUser?.uid else { throw FirestoreServiceError.notAuthenticated }

        let userSnap = try await db.collection("users").document(voterId).getDocument()
        let nickname = userSnap.data()?["nickname"] as? String ?? ""

        let submissionRef = db
            .collection("teams").document(teamId)
            .collection("dailyInstances").document(date)
            .collection("submissions").document(submissionId)

        let voteData: [String: Any] = [
            "voterId": voterId,
            "vote": vote, // "approve" or "reject"
            "votedAt": FieldValue.serverTimestamp(),
            "voterNickname": nickname,
        ]
        // Write the vote document (also triggers onVoteCast Cloud Function if deployed)
        try await submissionRef
            .collection("votes").document(voterId)
            .setData(voteData)

        // Record this voter's UID on the submission document so the client can
        // filter out already-voted submissions across tab switches and app restarts.
        try await submissionRef.updateData([
            "voterIds": FieldValue.arrayUnion([voterId])
        ])

        // ── Client-side approval fallback ──────────────────────────────────────
        // Check majority by counting votes in the subcollection, then mark the
        // submission approved if the threshold is met.  This runs in parallel
        // with the Cloud Function; both are idempotent (status=="pending" guard).
        let submissionSnap = try await submissionRef.getDocument()
        let submissionData = submissionSnap.data() ?? [:]
        guard submissionData["status"] as? String == "pending" else { return }

        let submitterUid = submissionData["submitterUid"] as? String ?? ""

        // Use live member count − 1 as the authoritative eligible voter count.
        // This corrects submissions whose eligibleVoterCount was mistakenly
        // stored as members.count (which includes the non-voting submitter).
        let effectiveEligibleVoterCount = max(1, members.count - 1)

        // Count approve votes directly from the subcollection
        let votesSnap = try await submissionRef.collection("votes").getDocuments()
        let approveCount = votesSnap.documents.filter {
            $0.data()["vote"] as? String == "approve"
        }.count

        // Majority: strictly more than half of eligible voters
        guard Double(approveCount) > Double(effectiveEligibleVoterCount) / 2.0 else { return }

        // Mark submission approved
        try? await submissionRef.updateData([
            "status": "approved",
            "approvalMethod": "peer_vote",
            "appUnlocked": true,
            "approvedAt": FieldValue.serverTimestamp(),
            "approveCount": approveCount,
        ])

        // Update submitter's member doc (mirrors what Cloud Function does)
        try? await db
            .collection("teams").document(teamId)
            .collection("members").document(submitterUid)
            .updateData([
                "lastApprovedDate": date,
                "consecutiveMisses": 0,
                "shardStatus": "active",
            ])
    }

    // MARK: - Proof Submission

    /// Uploads a proof photo to Firebase Storage and writes the submission document to Firestore.
    /// Document ID is `{uid}_{activityId}` so one submission per user per activity per day.
    /// Triggers the `onSubmissionCreated` Cloud Function which sends FCM vote-needed push notifications.
    func submitProof(teamId: String, image: UIImage, activityName: String, activityId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw FirestoreServiceError.notAuthenticated }

        // Fetch caller's profile for denormalized fields
        let userSnap = try await db.collection("users").document(uid).getDocument()
        let userData = userSnap.data() ?? [:]
        let displayName = userData["displayName"] as? String ?? ""
        let nickname = userData["nickname"] as? String ?? ""
        let avatarAssetName = userData["avatarAssetName"] as? String ?? ""

        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            throw FirestoreServiceError.invalidResponse
        }

        // Upload to Firebase Storage: proof/{teamId}/{date}/{uid}_{activityId}.jpg
        let dateString = Self.todayString(in: adminTimezone ?? "UTC")
        let storagePath = "proof/\(teamId)/\(dateString)/\(uid)_\(activityId).jpg"
        let storageRef = Storage.storage().reference(withPath: storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()

        // Eligible voters = everyone except the submitter themselves.
        // (Bug fix: previously used members.count which included the submitter,
        // making majority impossible for 2-person teams: 1 > 2/2=1 is false.)
        let memberCount = max(1, members.count - 1)

        // Composite doc ID: one submission per user per activity per day
        let submissionDocId = "\(uid)_\(activityId)"

        // Write submission document — triggers onSubmissionCreated Cloud Function
        // Copy activity name once so we own it before any work (avoids EXC_BAD_ACCESS if caller was deallocated).
        // Use a neutral fallback so we never store "Activity" (which can be confused with a group/activity name).
        let activityNameCopy = String(activityName)
        let nameToStore = activityNameCopy.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalActivityName = nameToStore.isEmpty ? "Proof" : nameToStore
        let submissionData: [String: Any] = [
            "submitterUid": uid,
            "activityId": activityId,
            "displayName": displayName,
            "nickname": nickname,
            "avatarAssetName": avatarAssetName,
            "activityName": finalActivityName,
            "photoUrl": downloadURL.absoluteString,
            "status": "pending",
            "approveCount": 0,
            "rejectCount": 0,
            "voteCount": 0,
            "eligibleVoterCount": memberCount,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        try await db
            .collection("teams").document(teamId)
            .collection("dailyInstances").document(dateString)
            .collection("submissions").document(submissionDocId)
            .setData(submissionData)
    }

    /// Returns today's date as "yyyy-MM-dd" in UTC — matches the format used by Firestore listeners.
    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    // MARK: - Goal CRUD (Edit Team)

    func addGoal(teamId: String, payload: ActivityPayload) async throws {
        let callable = functions.httpsCallable("addGoal")
        let params: [String: Any] = [
            "teamId": teamId,
            "payload": [
                "name": payload.name,
                "description": payload.description,
                "iconName": payload.iconName,
                "repeatDays": payload.repeatDays,
                "isOptional": payload.isOptional,
                "order": payload.order
            ]
        ]
        try await callable.call(params)
    }

    func updateGoal(teamId: String, goalId: String, payload: ActivityPayload) async throws {
        let callable = functions.httpsCallable("updateGoal")
        let params: [String: Any] = [
            "teamId": teamId,
            "goalId": goalId,
            "payload": [
                "name": payload.name,
                "description": payload.description,
                "iconName": payload.iconName,
                "repeatDays": payload.repeatDays,
                "isOptional": payload.isOptional,
                "order": payload.order
            ]
        ]
        try await callable.call(params)
    }

    func deleteGoal(teamId: String, goalId: String) async throws {
        let callable = functions.httpsCallable("deleteGoal")
        try await callable.call(["teamId": teamId, "goalId": goalId])
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
    static func todayString(in timezoneIdentifier: String) -> String {
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
    let optedInActivityIds: [String]

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        self.id = document.documentID
        self.displayName = data["displayName"] as? String ?? ""
        self.nickname = data["nickname"] as? String ?? ""
        self.avatarAssetName = data["avatarAssetName"] as? String ?? ""
        self.role = data["role"] as? String ?? "member"
        self.optedInActivityIds = data["optedInActivityIds"] as? [String] ?? []
        if let ts = data["joinedAt"] as? Timestamp {
            self.joinedAt = ts.dateValue()
        } else {
            self.joinedAt = nil
        }
    }
}

struct Submission: Identifiable, Equatable {
    let id: String
    let submitterUid: String
    let activityId: String
    let displayName: String
    let nickname: String
    let avatarAssetName: String
    let activityName: String
    let status: String
    let approvalsReceived: Int
    let approvalsRequired: Int
    let photoUrl: String?
    /// UIDs of users who have already cast a vote on this submission.
    /// Written via `arrayUnion` in `castVote()` so it survives view lifecycle.
    let voterIds: [String]

    init?(dictionary: [String: Any]) {
        // Prefer submissionId (Firestore doc ID) for per-activity submissions; fall back for legacy docs.
        let submissionId = dictionary["submissionId"] as? String
        let submitterUidFromData = dictionary["submitterUid"] as? String
        let legacyUid = dictionary["uid"] as? String ?? submitterUidFromData

        guard let id = submissionId ?? legacyUid else { return nil }
        self.id = id
        self.submitterUid = submitterUidFromData ?? legacyUid ?? id
        self.activityId = dictionary["activityId"] as? String ?? ""
        self.displayName = dictionary["displayName"] as? String ?? ""
        self.nickname = dictionary["nickname"] as? String ?? ""
        self.avatarAssetName = dictionary["avatarAssetName"] as? String ?? ""
        self.activityName = dictionary["activityName"] as? String ?? ""
        self.status = dictionary["status"] as? String ?? "pending"
        self.approvalsReceived = dictionary["approvalsReceived"] as? Int
            ?? dictionary["approveCount"] as? Int
            ?? dictionary["approvedCount"] as? Int
            ?? 0
        self.approvalsRequired = dictionary["approvalsRequired"] as? Int
            ?? dictionary["eligibleVoterCount"] as? Int
            ?? 0
        self.photoUrl = dictionary["photoUrl"] as? String
        self.voterIds = dictionary["voterIds"] as? [String] ?? []
    }
}

/// A team goal/activity pulled from `teams/{teamId}/goals`, used in the upload proof flow.
struct TeamActivity: Identifiable {
    let id: String          // Firestore document ID
    let name: String
    let iconName: String
    let activityDescription: String
    let repeatDays: [Int]
    let isOptional: Bool
    let order: Int

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let name = data["name"] as? String else { return nil }
        self.id = document.documentID
        self.name = name
        self.iconName = data["iconName"] as? String ?? "checkmark.circle"
        self.activityDescription = data["description"] as? String ?? ""
        self.repeatDays = data["repeatDays"] as? [Int] ?? []
        self.isOptional = data["isOptional"] as? Bool ?? false
        self.order = data["order"] as? Int ?? 0
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

