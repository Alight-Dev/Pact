// manageGoal — HTTP Callables
//
// addGoal, updateGoal, deleteGoal — admin-only CRUD for team goals.
// Direct client writes to teams/{teamId}/goals are blocked by Firestore rules;
// these functions use the Admin SDK to bypass them after verifying admin role.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { ActivityPayload } from "./types";

const db = getFirestore();

async function assertAdmin(uid: string | undefined, teamId: string): Promise<void> {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!teamId?.trim()) throw new HttpsError("invalid-argument", "teamId is required.");
  const memberSnap = await db.collection("teams").doc(teamId)
    .collection("members").doc(uid).get();
  if (!memberSnap.exists || memberSnap.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Only team admins can manage goals.");
  }
}

export const addGoal = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  const { teamId, payload } = request.data as { teamId: string; payload: ActivityPayload };
  await assertAdmin(uid, teamId);

  const goalRef = db.collection("teams").doc(teamId).collection("goals").doc();
  await goalRef.set({
    goalId: goalRef.id,
    teamId,
    name: payload.name,
    description: payload.description,
    iconName: payload.iconName,
    repeatDays: payload.repeatDays,
    order: payload.order,
    restrictedAppBundleIds: [],
    familyActivitySelection: "",
    dailyDeadlineMinutesUTC: 0,
    forgeStatus: "active",
    agreedMemberIds: [],
    agreedCount: 0,
    createdAt: Timestamp.now(),
    activatedAt: null,
    createdBy: uid,
  });
  return { goalId: goalRef.id };
});

export const updateGoal = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  const { teamId, goalId, payload } = request.data as {
    teamId: string; goalId: string; payload: ActivityPayload;
  };
  await assertAdmin(uid, teamId);
  if (!goalId?.trim()) throw new HttpsError("invalid-argument", "goalId is required.");

  await db.collection("teams").doc(teamId).collection("goals").doc(goalId).update({
    name: payload.name,
    description: payload.description,
    iconName: payload.iconName,
    repeatDays: payload.repeatDays,
    order: payload.order,
  });
  return { success: true };
});

export const deleteGoal = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  const { teamId, goalId } = request.data as { teamId: string; goalId: string };
  await assertAdmin(uid, teamId);
  if (!goalId?.trim()) throw new HttpsError("invalid-argument", "goalId is required.");

  await db.collection("teams").doc(teamId).collection("goals").doc(goalId).delete();
  return { success: true };
});
