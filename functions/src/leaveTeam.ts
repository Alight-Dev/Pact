// CF-9: leaveTeam — HTTP Callable
//
// Removes the calling user from their team.
// If the caller is the admin and other members remain, they must supply
// newAdminUid to transfer admin role before leaving.
// If the user is the last member, the team document and its invite code are
// permanently deleted (dissolved).
//
// Returns { dissolved: boolean } — true when the team was fully deleted.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { todayInTimezone } from "./types";

const db = getFirestore();

export const leaveTeam = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { teamId, newAdminUid } = request.data as {
      teamId: string;
      newAdminUid?: string;
    };
    if (!teamId) throw new HttpsError("invalid-argument", "teamId is required.");

    // 1. Load the team document
    const teamRef = db.collection("teams").doc(teamId);
    const teamSnap = await teamRef.get();
    if (!teamSnap.exists) {
      throw new HttpsError("not-found", "Team not found.");
    }
    const teamData = teamSnap.data()!;

    // 2. Verify the caller is actually a member
    const memberRef = teamRef.collection("members").doc(uid);
    const memberSnap = await memberRef.get();
    if (!memberSnap.exists) {
      throw new HttpsError("not-found", "You are not a member of this team.");
    }
    const memberData = memberSnap.data()!;
    const isAdmin = memberData.role === "admin" || teamData.adminId === uid;

    // 3. Load user's membership record
    const membershipRef = db.collection("users").doc(uid)
      .collection("teamMemberships").doc(teamId);

    const inviteCode: string = teamData.inviteCode ?? "";
    const memberCount: number = teamData.memberCount ?? 0;
    const isLastMember = memberCount <= 1;

    // 4. Admin-specific logic: auto-pick oldest other member as new admin
    let resolvedNewAdminUid: string | undefined = newAdminUid;
    if (isAdmin && !isLastMember) {
      if (newAdminUid) {
        // Caller specified a successor — verify they're a member
        const newAdminMemberSnap = await teamRef.collection("members").doc(newAdminUid).get();
        if (!newAdminMemberSnap.exists) {
          throw new HttpsError(
            "invalid-argument",
            "The selected user is not a member of this team."
          );
        }
      } else {
        // Auto-pick the oldest other member (earliest joinedAt) as new admin
        const otherMembersSnap = await teamRef
          .collection("members")
          .orderBy("joinedAt", "asc")
          .limit(2)
          .get();
        const otherMember = otherMembersSnap.docs.find((d) => d.id !== uid);
        if (otherMember) {
          resolvedNewAdminUid = otherMember.id;
        }
      }
    }

    const batch = db.batch();

    if (isLastMember) {
      // Dissolve the team entirely
      batch.delete(teamRef);
      if (inviteCode) {
        batch.delete(db.collection("invites").doc(inviteCode));
      }
      batch.delete(memberRef);
      batch.delete(membershipRef);
    } else {
      // Transfer admin role if needed
      if (isAdmin && resolvedNewAdminUid) {
        batch.update(teamRef, { adminId: resolvedNewAdminUid });
        batch.update(teamRef.collection("members").doc(resolvedNewAdminUid), { role: "admin" });
      }

      // Remove the leaving member
      batch.update(teamRef, {
        memberCount: FieldValue.increment(-1),
        todayTotalMembers: FieldValue.increment(-1),
      });
      if (inviteCode) {
        batch.update(db.collection("invites").doc(inviteCode), {
          memberCount: FieldValue.increment(-1),
        });
      }
      batch.delete(memberRef);
      batch.delete(membershipRef);
    }

    await batch.commit();

    // 5. If not the last member, decrement eligibleVoterCount on today's
    //    pending submissions so majority thresholds remain correct.
    if (!isLastMember) {
      const adminTimezone: string = teamData.adminTimezone ?? "UTC";
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
            eligibleVoterCount: FieldValue.increment(-1),
          });
        }
        await updateBatch.commit();
      }
    }

    return { dissolved: isLastMember };
  }
);
