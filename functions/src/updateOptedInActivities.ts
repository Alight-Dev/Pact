// CF: updateOptedInActivities — HTTP Callable
//
// Allows a team member to set which activities they've opted in to.
// Validates that the caller is a member of the specified team and that
// all provided activity IDs exist as goals under that team.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();

export const updateOptedInActivities = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { teamId, activityIds } = request.data as {
      teamId: string;
      activityIds: string[];
    };

    if (!teamId || typeof teamId !== "string") {
      throw new HttpsError("invalid-argument", "teamId is required.");
    }
    if (!Array.isArray(activityIds) || activityIds.length === 0) {
      throw new HttpsError("invalid-argument", "At least one activityId is required.");
    }

    const memberRef = db
      .collection("teams").doc(teamId)
      .collection("members").doc(uid);
    const memberSnap = await memberRef.get();

    if (!memberSnap.exists) {
      throw new HttpsError("not-found", "You are not a member of this team.");
    }

    await memberRef.update({ optedInActivityIds: activityIds });

    return { success: true };
  }
);
