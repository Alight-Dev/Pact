// CF: onSubmissionRetaken — Firestore onUpdate trigger
//
// Fires whenever a submission document is updated.
// Acts only when the status transitions "rejected" → "pending", which happens
// when a user retakes their proof photo via submitProof() (client .setData overwrite).
//
// 1. Deletes all stale vote documents so members can vote fresh on the new photo.
// 2. Sends FCM "vote needed" to every member except the submitter.

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();

export const onSubmissionRetaken = onDocumentUpdated(
  {
    document: "teams/{teamId}/dailyInstances/{date}/submissions/{submissionId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();

    // Only act on the specific rejected → pending transition
    if (before?.status !== "rejected" || after?.status !== "pending") return;

    const { teamId, date } = event.params;
    const submissionRef = event.data!.after.ref;
    const submitterUid: string = after.submitterUid ?? "";

    // 1. Delete all stale vote documents in a single batched write
    const votesSnap = await submissionRef.collection("votes").get();
    if (!votesSnap.empty) {
      const batch = db.batch();
      votesSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    // 2. Send FCM "vote needed" to all members except the submitter
    const membersSnap = await db
      .collection("teams").doc(teamId)
      .collection("members")
      .get();

    const tokens: string[] = membersSnap.docs
      .filter((d) => d.id !== submitterUid)
      .map((d) => d.data().fcmToken as string | null)
      .filter((t): t is string => !!t);

    if (tokens.length === 0) return;

    const nickname: string    = after.nickname ?? after.displayName ?? "A teammate";
    const activityName: string = after.activityName ?? "their proof";

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "New photo — vote needed 🔄",
        body: `${nickname} retook their ${activityName} proof. Tap to vote →`,
      },
      data: {
        type: "vote_needed",
        teamId,
        date,
        submitterUid,
        activityName,
        submitterNickname: nickname,
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    });
  }
);
