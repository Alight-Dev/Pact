// updateTeamSettings — HTTP Callable
//
// Admin-only update for team approval settings.
// Direct client writes to teams/{teamId} are blocked by Firestore rules;
// this function uses the Admin SDK to bypass them after verifying admin role.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();

async function assertAdmin(uid: string | undefined, teamId: string): Promise<void> {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!teamId?.trim()) throw new HttpsError("invalid-argument", "teamId is required.");
  const memberSnap = await db.collection("teams").doc(teamId)
    .collection("members").doc(uid).get();
  if (!memberSnap.exists || memberSnap.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Only team admins can update settings.");
  }
}

export const updateTeamSettings = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  const { teamId, approvalMode, allowAIFallback } = request.data as {
    teamId: string;
    approvalMode: string;
    allowAIFallback: boolean;
  };
  await assertAdmin(uid, teamId);

  // Compute minimumRequiredVoters server-side from member count
  const membersSnap = await db.collection("teams").doc(teamId).collection("members").count().get();
  const memberCount = membersSnap.data().count;

  let minimumRequiredVoters: number;
  switch (approvalMode) {
    case "one_person":
      minimumRequiredVoters = 1;
      break;
    case "entire_team":
      minimumRequiredVoters = Math.max(1, memberCount - 1);
      break;
    default: // "majority"
      minimumRequiredVoters = Math.max(1, Math.floor((memberCount - 1) / 2) + 1);
      break;
  }

  await db.collection("teams").doc(teamId).update({
    approvalMode,
    minimumRequiredVoters,
    allowAIFallback,
  });

  return { success: true };
});
