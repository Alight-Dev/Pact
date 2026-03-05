// CF-1: onVoteCast — Firestore onCreate trigger
//
// Fires when a member casts a vote on a submission (submission doc ID = uid_activityId).
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
      "teams/{teamId}/dailyInstances/{date}/submissions/{submissionId}/votes/{voterId}",
    region: "us-central1",
  },
  async (event) => {
    const { teamId, date, submissionId } = event.params;
    const vote = event.data?.data();
    if (!vote) return;

    const voteValue: string = vote.vote; // "approve" | "reject"

    const submissionRef = db
      .collection("teams").doc(teamId)
      .collection("dailyInstances").doc(date)
      .collection("submissions").doc(submissionId);

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

    const submitterUid: string = submission.submitterUid ?? submissionId.split("_")[0] ?? "";

    const approveCount: number = submission.approveCount ?? 0;
    const rejectCount: number = submission.rejectCount ?? 0;
    const eligibleVoterCount: number = submission.eligibleVoterCount ?? 1;

    // Majority check: strictly more than half of eligible voters
    const approveMajority = approveCount > eligibleVoterCount / 2;
    const rejectMajority = rejectCount > eligibleVoterCount / 2;
    if (!approveMajority && !rejectMajority) return;

    const instanceRef = db
      .collection("teams").doc(teamId)
      .collection("dailyInstances").doc(date);
    const now = Timestamp.now();

    if (approveMajority) {
      // ── Submission approved ───────────────────────────────────────────────

      // Update submission doc
      await submissionRef.update({
        status: "approved",
        approvalMethod: "peer_vote",
        approvedAt: now,
        appUnlocked: true,
      });

      // Increment approvedCount on dailyInstances, decrement pendingCount
      const instanceSnap = await instanceRef.get();
      const instance = instanceSnap.data() ?? {};

      const newApprovedCount = (instance.approvedCount ?? 0) + 1;
      const expectedSubmissionCount: number = instance.expectedSubmissionCount ?? instance.totalMembers ?? 1;
      const allApproved = newApprovedCount >= expectedSubmissionCount;

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
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });
      }

      // daily_complete check — notify all members if every expected submission is approved
      if (allApproved) {
        const submissionsSnap = await instanceRef.collection("submissions").get();
        const teamMembersSnap = await db
          .collection("teams").doc(teamId)
          .collection("members").get();

        const allDone = submissionsSnap.docs.every((d) => {
          const s = d.data().status as string;
          return s === "approved" || s === "auto_approved";
        });

        if (allDone && submissionsSnap.size >= expectedSubmissionCount) {
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
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                  },
                },
              },
            });
          }
        }
      }

    } else {
      // ── Submission rejected ───────────────────────────────────────────────

      await submissionRef.update({
        status: "rejected",
        rejectedAt: now,
      });

      await instanceRef.update({
        rejectedCount: FieldValue.increment(1),
        pendingCount: FieldValue.increment(-1),
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
            title: "Proof rejected",
            body: "Your team didn't approve your submission. Try again tomorrow.",
          },
          data: {
            type: "submission_rejected",
            teamId,
            date,
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

      return;
    }
  }
);
