// CF-2: onSubmissionCreated — Firestore onCreate trigger
//
// Fires when a member creates their daily submission (doc ID = uid_activityId).
// 1. Lazily creates the dailyInstances/{date} doc if missing (with expectedSubmissionCount).
// 2. Increments pendingCount.
// 3. Sends FCM "vote needed" to all other members.

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();

export const onSubmissionCreated = onDocumentCreated(
  {
    document: "teams/{teamId}/dailyInstances/{date}/submissions/{submissionId}",
    region: "us-central1",
  },
  async (event) => {
    const { teamId, date, submissionId } = event.params;
    const submission = event.data?.data();
    if (!submission) return;

    const submitterUid: string = submission.submitterUid ?? submissionId.split("_")[0] ?? "";

    const teamRef = db.collection("teams").doc(teamId);
    const instanceRef = teamRef.collection("dailyInstances").doc(date);

    // 1. Lazily create dailyInstances/{date} if it doesn't exist
    const instanceSnap = await instanceRef.get();
    if (!instanceSnap.exists) {
      const teamSnap = await teamRef.get();
      const teamData = teamSnap.data() ?? {};
      const goalsSnap = await teamRef.collection("goals").get();
      const goalIds = goalsSnap.docs.map((d) => d.id);
      const membersSnapForInstance = await teamRef.collection("members").get();
      const totalMembers = membersSnapForInstance.size;
      // Expected submissions = sum over members of (opted-in count or all goals if empty)
      const expectedSubmissionCount = membersSnapForInstance.docs.reduce((sum, doc) => {
        const optedIn: string[] = doc.data().optedInActivityIds ?? [];
        const count = optedIn.length > 0 ? optedIn.length : Math.max(goalIds.length, 1);
        return sum + count;
      }, 0);

      await instanceRef.set({
        teamId,
        date,
        goalId: teamData.currentGoalId ?? null,
        totalMembers,
        expectedSubmissionCount: Math.max(expectedSubmissionCount, 1),
        approvedCount: 0,
        pendingCount: 0,
        missedCount: 0,
        allApproved: false,
        streakProcessed: false,
        createdAt: Timestamp.now(),
        cutoffAt: Timestamp.fromDate(
          new Date(`${date}T23:59:59Z`)
        ),
      });
    }

    // 2. Increment pendingCount on the dailyInstance
    await instanceRef.update({
      pendingCount: FieldValue.increment(1),
    });

    // 3. FCM "vote needed" to all members except the submitter
    const membersSnap = await teamRef.collection("members").get();
    const tokens: string[] = membersSnap.docs
      .filter((d) => d.id !== submitterUid)
      .map((d) => d.data().fcmToken as string | null)
      .filter((t): t is string => !!t);

    if (tokens.length > 0) {
      const submitterNickname: string =
        submission.nickname ?? submission.displayName ?? "A teammate";
      const activityName: string = submission.activityName ?? "their proof";

      await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New submission",
          body: `${submitterNickname} submitted their ${activityName} proof. Tap to vote →`,
        },
        data: {
          type: "vote_needed",
          teamId,
          date,
          submitterUid,
          activityName,
          submitterNickname,
        },
      });
    }
  }
);
