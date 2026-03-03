// CF-3: onForgePactAgreement — Firestore onCreate trigger
//
// Fires when any member writes their forgePactAgreement doc.
// Increments agreedCount on the goal; when all members have agreed,
// activates the goal (forgeStatus → "active") and sends FCM.

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();

export const onForgePactAgreement = onDocumentCreated(
  {
    document: "teams/{teamId}/goals/{goalId}/forgePactAgreements/{uid}",
    region: "us-central1",
  },
  async (event) => {
    const { teamId, goalId, uid } = event.params;
    const agreementData = event.data?.data();
    if (!agreementData) return;

    const goalRef = db.collection("teams").doc(teamId).collection("goals").doc(goalId);
    const teamRef = db.collection("teams").doc(teamId);

    // Atomically increment agreedCount and append uid
    await goalRef.update({
      agreedCount: FieldValue.increment(1),
      agreedMemberIds: FieldValue.arrayUnion(uid),
    });

    // Re-read to check if all members have agreed
    const [goalSnap, teamSnap] = await Promise.all([
      goalRef.get(),
      teamRef.get(),
    ]);

    const goalData = goalSnap.data();
    const teamData = teamSnap.data();
    if (!goalData || !teamData) return;

    const agreedCount: number = goalData.agreedCount ?? 0;
    const memberCount: number = teamData.memberCount ?? 0;

    if (agreedCount < memberCount) return; // Not everyone agreed yet

    // All members agreed → activate the goal
    await goalRef.update({
      forgeStatus: "active",
      activatedAt: Timestamp.now(),
    });
    await teamRef.update({ currentGoalId: goalId });

    // Notify all members via FCM
    const membersSnap = await teamRef.collection("members").get();
    const tokens: string[] = membersSnap.docs
      .map((d) => d.data().fcmToken as string | null)
      .filter((t): t is string => !!t);

    if (tokens.length > 0) {
      await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "🛡 Pact Forged!",
          body: "All members agreed. The challenge starts today — don't break it.",
        },
        data: { type: "forge_pact_ready", teamId, goalId },
      });
    }
  }
);
