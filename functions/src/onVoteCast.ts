// CF-1: onVoteCast — Firestore onCreate trigger
//
// Fires when a member casts a vote on a submission.
// 1. Increments approve/rejectCount on the submission.
// 2. Checks majority: approveCount > eligibleVoterCount / 2
// 3. On approval: updates submission status, unlocks app, updates daily counts,
//    resets member shard, and sends FCM to the submitter.

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();

export const onVoteCast = onDocumentCreated(
  {
    document:
      "teams/{teamId}/dailyInstances/{date}/submissions/{submitterUid}/votes/{voterId}",
    region: "us-central1",
  },
  async (event) => {
    const { teamId, date, submitterUid } = event.params;
    const vote = event.data?.data();
    if (!vote) return;

    const voteValue: string = vote.vote; // "approve" | "reject"

    const submissionRef = db
      .collection("teams").doc(teamId)
      .collection("dailyInstances").doc(date)
      .collection("submissions").doc(submitterUid);

    // Increment the appropriate tally
    const incrementField =
      voteValue === "approve" ? "approveCount" : "rejectCount";
    await submissionRef.update({
      voteCount: FieldValue.increment(1),
      [incrementField]: FieldValue.increment(1),
    });

    // Re-read submission to check majority
    const submissionSnap = await submissionRef.get();
    const submission = submissionSnap.data();
    if (!submission || submission.status !== "pending") return;

    const approveCount: number = submission.approveCount ?? 0;
    const eligibleVoterCount: number = submission.eligibleVoterCount ?? 1;

    // Majority check: strictly more than half of eligible voters
    const majority = approveCount > eligibleVoterCount / 2;
    if (!majority) return;

    // ── Submission approved ─────────────────────────────────────────────────
    const now = Timestamp.now();

    // Update submission doc
    await submissionRef.update({
      status: "approved",
      approvalMethod: "peer_vote",
      approvedAt: now,
      appUnlocked: true,
    });

    // Increment approvedCount on dailyInstances, decrement pendingCount
    const instanceRef = db
      .collection("teams").doc(teamId)
      .collection("dailyInstances").doc(date);
    const instanceSnap = await instanceRef.get();
    const instance = instanceSnap.data() ?? {};

    const newApprovedCount = (instance.approvedCount ?? 0) + 1;
    const totalMembers: number = instance.totalMembers ?? 1;
    const allApproved = newApprovedCount >= totalMembers;

    await instanceRef.update({
      approvedCount: FieldValue.increment(1),
      pendingCount: FieldValue.increment(-1),
      allApproved,
    });

    // Update today's summary on the team doc
    await db.collection("teams").doc(teamId).update({
      todayApprovedCount: FieldValue.increment(1),
    });

    // Reset the submitter's shard state on the member doc
    await db
      .collection("teams").doc(teamId)
      .collection("members").doc(submitterUid)
      .update({
        lastApprovedDate: date,
        consecutiveMisses: 0,
        shardStatus: "active",
      });

    // FCM to the submitter
    const submitterMemberSnap = await db
      .collection("teams").doc(teamId)
      .collection("members").doc(submitterUid)
      .get();
    const submitterFcmToken: string | null =
      submitterMemberSnap.data()?.fcmToken ?? null;

    if (submitterFcmToken) {
      await getMessaging().send({
        token: submitterFcmToken,
        notification: {
          title: "Proof approved! 🎉",
          body: "Your team voted you in. Keep the streak alive!",
        },
        data: {
          type: "submission_approved",
          teamId,
          date,
        },
      });
    }

    // daily_complete check — notify all members if every submission is approved
    if (allApproved) {
      const submissionsSnap = await instanceRef.collection("submissions").get();
      const teamMembersSnap = await db
        .collection("teams").doc(teamId)
        .collection("members").get();

      const allDone = submissionsSnap.docs.every((d) => {
        const s = d.data().status as string;
        return s === "approved" || s === "auto_approved";
      });

      if (allDone && submissionsSnap.size >= teamMembersSnap.size) {
        const allTokens: string[] = teamMembersSnap.docs
          .map((d) => d.data().fcmToken as string | null)
          .filter((t): t is string => !!t);

        if (allTokens.length > 0) {
          await getMessaging().sendEachForMulticast({
            tokens: allTokens,
            notification: {
              title: "Pact complete! 🔥",
              body: "Every teammate finished today. Streak safe!",
            },
            data: { type: "daily_complete", teamId, date },
          });
        }
      }
    }
  }
);
