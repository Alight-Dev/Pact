// CF-7: joinTeam — HTTP Callable
//
// Validates the 6-digit invite code and atomically adds the caller as a member.
// Updates eligibleVoterCount on any in-progress submissions for today.
// Returns { teamId, teamName } on success.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { tierForStreak, todayInTimezone } from "./types";

const db = getFirestore();

export const joinTeam = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { inviteCode } = request.data as { inviteCode: string };
    if (!inviteCode || inviteCode.length !== 6) {
      throw new HttpsError("invalid-argument", "inviteCode must be 6 digits.");
    }

    // 1. Load invite
    const inviteSnap = await db.collection("invites").doc(inviteCode).get();
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite code not found.");
    }
    const invite = inviteSnap.data()!;
    if (!invite.isActive) {
      throw new HttpsError("failed-precondition", "This invite code is no longer active.");
    }
    if ((invite.memberCount ?? 0) >= (invite.maxMembers ?? 5)) {
      throw new HttpsError("resource-exhausted", "This team is already full (5/5).");
    }

    const teamId: string = invite.teamId;
    const teamName: string = invite.teamName;

    // 2. Enforce one-team-at-a-time: reject if user already belongs to any team
    const membershipsSnap = await db
      .collection("users").doc(uid)
      .collection("teamMemberships")
      .limit(1)
      .get();
    if (!membershipsSnap.empty) {
      throw new HttpsError(
        "already-exists",
        "You are already in a team. Leave your current team before joining another."
      );
    }

    // 2b. Check user isn't already a member of this specific team
    const existingMemberSnap = await db
      .collection("teams").doc(teamId)
      .collection("members").doc(uid)
      .get();
    if (existingMemberSnap.exists) {
      throw new HttpsError("already-exists", "You are already a member of this team.");
    }

    // 3. Load caller's user profile
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() ?? {};
    const nickname: string = userData.nickname ?? userData.displayName ?? "Member";
    const displayName: string = userData.displayName ?? "";
    const avatarAssetName: string = userData.avatarAssetName ?? "";

    // 4. Load team doc for shield tier / streak snapshot
    const teamSnap = await db.collection("teams").doc(teamId).get();
    const teamData = teamSnap.data() ?? {};
    const adminTimezone: string = teamData.adminTimezone ?? "UTC";

    const now = Timestamp.now();
    const batch = db.batch();

    // teams/{teamId}/members/{uid}
    const memberRef = db.collection("teams").doc(teamId).collection("members").doc(uid);
    batch.set(memberRef, {
      userId: uid,
      displayName,
      nickname,
      avatarAssetName,
      role: "member",
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

    // Increment memberCount on teams/{teamId}
    batch.update(db.collection("teams").doc(teamId), {
      memberCount: FieldValue.increment(1),
      todayTotalMembers: FieldValue.increment(1),
    });

    // Increment memberCount on invites/{code}
    batch.update(db.collection("invites").doc(inviteCode), {
      memberCount: FieldValue.increment(1),
    });

    // users/{uid}/teamMemberships/{teamId}
    const membershipRef = db.collection("users").doc(uid)
      .collection("teamMemberships").doc(teamId);
    batch.set(membershipRef, {
      teamId,
      teamName,
      role: "member",
      joinedAt: now,
      shardStatus: "active",
      shieldTier: teamData.shieldTier ?? tierForStreak(0),
      currentStreakDays: teamData.currentStreakDays ?? 0,
      adminTimezone,   // required by loadActiveMembership() for correct "today" calculation
    });

    await batch.commit();

    // 5. Notify existing members that a new member joined.
    //    Read member docs AFTER batch.commit() so the new member doc exists,
    //    then filter by uid so we don't notify the joiner themselves.
    const allMembersSnap = await db.collection("teams").doc(teamId).collection("members").get();
    const existingMemberTokens: string[] = allMembersSnap.docs
      .filter((d) => d.id !== uid)
      .map((d) => d.data().fcmToken as string | null)
      .filter((t): t is string => !!t);

    if (existingMemberTokens.length > 0) {
      await getMessaging().sendEachForMulticast({
        tokens: existingMemberTokens,
        notification: {
          title: "New Teammate!",
          body: `${nickname} just joined your team.`,
        },
        data: {
          type: "team_joined",
          teamId,
          joinerUid: uid,
          joinerNickname: nickname,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
    }

    // 6. Update eligibleVoterCount on today's pending submissions
    //    (so majority can never be achieved with stale voter count)
    const todayDate = todayInTimezone(adminTimezone);
    const submissionsSnap = await db
      .collection("teams").doc(teamId)
      .collection("dailyInstances").doc(todayDate)
      .collection("submissions")
      .where("status", "==", "pending")
      .get();

    if (!submissionsSnap.empty) {
      const updateBatch = db.batch();
      for (const doc of submissionsSnap.docs) {
        updateBatch.update(doc.ref, {
          eligibleVoterCount: FieldValue.increment(1),
        });
      }
      await updateBatch.commit();
    }

    return { teamId, teamName };
  }
);
