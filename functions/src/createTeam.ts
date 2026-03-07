// CF-8: createTeam — HTTP Callable
//
// Creates a new team, writes the first goal from ActivityListView activities,
// generates a unique 6-digit invite code, and fans out to teamMemberships.
// Returns { teamId, inviteCode } to the iOS caller.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { ActivityPayload, tierForStreak, todayInTimezone } from "./types";

const db = getFirestore();

// Generate a random 6-digit numeric code and verify no collision in /invites.
async function generateUniqueCode(): Promise<string> {
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    const snap = await db.collection("invites").doc(code).get();
    if (!snap.exists) return code;
  }
  throw new HttpsError("internal", "Could not generate a unique invite code. Please try again.");
}

export const createTeam = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { teamName, activities, adminTimezone } = request.data as {
      teamName: string;
      activities: ActivityPayload[];
      adminTimezone: string;
    };

    if (!teamName?.trim()) throw new HttpsError("invalid-argument", "teamName is required.");
    if (!activities?.length) throw new HttpsError("invalid-argument", "At least one activity is required.");

    // Enforce one-team-at-a-time on the server
    const existingMemberships = await db
      .collection("users").doc(uid)
      .collection("teamMemberships")
      .limit(1)
      .get();
    if (!existingMemberships.empty) {
      throw new HttpsError(
        "already-exists",
        "You are already in a team. Leave your current team before creating a new one."
      );
    }

    // Read the caller's user profile for denormalized fields
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() ?? {};
    const adminNickname: string = userData.nickname ?? userData.displayName ?? "Admin";
    const adminDisplayName: string = userData.displayName ?? "";
    const adminAvatarAssetName: string = userData.avatarAssetName ?? "";

    const inviteCode = await generateUniqueCode();
    const teamRef = db.collection("teams").doc();
    const teamId = teamRef.id;
    const now = Timestamp.now();
    const todayDate = todayInTimezone(adminTimezone || "UTC");

    // Pre-compute all goal refs so currentGoalId is known before the batch starts.
    const goalRefs = activities.map(() => teamRef.collection("goals").doc());
    const firstGoalId = goalRefs[0].id;

    // Write everything atomically
    const batch = db.batch();

    // teams/{teamId}
    batch.set(teamRef, {
      teamId,
      name: teamName.trim(),
      adminId: uid,
      inviteCode,
      memberCount: 1,
      maxMembers: 5,
      createdAt: now,
      currentGoalId: firstGoalId,
      dailyCutoffUTC: 0,
      adminTimezone: adminTimezone || "UTC",
      shieldTier: tierForStreak(0),
      currentStreakDays: 0,
      lastStreakDate: "",
      bestStreakDays: 0,
      streakComputedAt: now,
      todayApprovedCount: 0,
      todayTotalMembers: 1,
      todayDate,
    });

    // teams/{teamId}/members/{uid}
    const memberRef = teamRef.collection("members").doc(uid);
    batch.set(memberRef, {
      userId: uid,
      displayName: adminDisplayName,
      nickname: adminNickname,
      avatarAssetName: adminAvatarAssetName,
      role: "admin",
      joinedAt: now,
      optedInActivityIds: [],
      shardStatus: "active",
      consecutiveMisses: 0,
      lastApprovedDate: null,
      lastSubmissionDate: null,
      lockShieldActive: false,
      lastSystemLockDate: "",
      fcmToken: userData.fcmTokens?.[0] ?? null,
    });

    // invites/{code}
    const inviteRef = db.collection("invites").doc(inviteCode);
    batch.set(inviteRef, {
      inviteCode,
      teamId,
      teamName: teamName.trim(),
      adminNickname,
      memberCount: 1,
      maxMembers: 5,
      createdAt: now,
      expiresAt: null,
      isActive: true,
    });

    // users/{uid}/teamMemberships/{teamId}
    const membershipRef = db.collection("users").doc(uid)
      .collection("teamMemberships").doc(teamId);
    batch.set(membershipRef, {
      teamId,
      teamName: teamName.trim(),
      role: "admin",
      joinedAt: now,
      shardStatus: "active",
      shieldTier: tierForStreak(0),
      currentStreakDays: 0,
    });

    // Create goal docs for each activity
    for (const [i, activity] of activities.entries()) {
      const goalRef = goalRefs[i];
      batch.set(goalRef, {
        goalId: goalRef.id,
        teamId,
        name: activity.name,
        description: activity.description,
        iconName: activity.iconName,
        repeatDays: activity.repeatDays,
        order: activity.order,
        restrictedAppBundleIds: [],
        familyActivitySelection: "",
        dailyDeadlineMinutesUTC: 0,
        forgeStatus: i === 0 ? "pending_forge" : "pending_forge",
        agreedMemberIds: [],
        agreedCount: 0,
        createdAt: now,
        activatedAt: null,
        createdBy: uid,
      });
    }

    await batch.commit();

    return { teamId, inviteCode };
  }
);
