// CF: sendNudge — HTTP Callable
//
// Sends a push notification to a teammate who hasn't yet voted on a pending
// submission, reminding them to review.  Rate-limiting is handled client-side;
// this function sends the FCM message without further throttling.
//
// Request payload:
//   { teamId: string, date: string, submissionId: string, targetUid: string }
//
// Response:
//   { success: true }

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();

export const sendNudge = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const { teamId, date, submissionId, targetUid } = request.data as {
      teamId: string;
      date: string;
      submissionId: string;
      targetUid: string;
    };

    if (!teamId || !date || !submissionId || !targetUid) {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    // Prevent self-nudge
    if (request.auth.uid === targetUid) {
      throw new HttpsError("invalid-argument", "Cannot nudge yourself.");
    }

    // Fetch submission details for the notification body
    const submissionSnap = await db
      .collection("teams").doc(teamId)
      .collection("dailyInstances").doc(date)
      .collection("submissions").doc(submissionId)
      .get();

    const submissionData = submissionSnap.data();
    if (!submissionData) {
      throw new HttpsError("not-found", "Submission not found.");
    }

    const submitterNickname: string =
      submissionData.nickname ?? submissionData.displayName ?? "A teammate";
    const activityName: string = submissionData.activityName ?? "their proof";

    // Fetch the target member's FCM token
    const memberSnap = await db
      .collection("teams").doc(teamId)
      .collection("members").doc(targetUid)
      .get();

    const fcmToken = memberSnap.data()?.fcmToken as string | undefined;
    if (!fcmToken) {
      // No token stored — silently succeed so the client isn't stuck
      return { success: true };
    }

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "Don't forget to vote! 👀",
        body: `${submitterNickname} is waiting for your review on ${activityName}.`,
      },
      data: {
        type: "vote_needed",
        teamId,
        date,
        submitterUid: submissionData.submitterUid ?? "",
        activityName,
        submitterNickname,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    return { success: true };
  }
);
