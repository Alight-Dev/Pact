//
// processStreakForDate — HTTP Callable
//
// Allows a team admin to run streak processing for a given date (e.g. to fix
// currentStreakDays when the real-time update didn't run or to repair state).
// Optional force: true re-applies team/member updates even if the date was already processed.
//

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { processDateForStreak } from "./dailyStreakProcessor";
import { isDayFullyApproved } from "./streakHelpers";

const db = getFirestore();

export const processStreakForDate = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { teamId, date, force } = request.data as {
      teamId: string;
      date: string;
      force?: boolean;
    };

    if (!teamId || !date) {
      throw new HttpsError("invalid-argument", "teamId and date are required.");
    }

    const teamRef = db.collection("teams").doc(teamId);
    const teamSnap = await teamRef.get();
    if (!teamSnap.exists) {
      throw new HttpsError("not-found", "Team not found.");
    }
    const teamData = teamSnap.data()!;
    const adminId = teamData.adminId as string | undefined;
    if (adminId !== uid) {
      throw new HttpsError("permission-denied", "Only the team admin can run streak processing.");
    }

    const instanceRef = teamRef.collection("dailyInstances").doc(date);
    const instanceSnap = await instanceRef.get();
    if (!instanceSnap.exists) {
      throw new HttpsError("not-found", "No daily instance for this date.");
    }

    const { allApproved } = await isDayFullyApproved(teamId, date);
    const now = Timestamp.now();
    await processDateForStreak(teamId, date, teamData, now, {
      resetTodayCounters: false,
      force: force === true,
    });

    const updated = (await teamRef.get()).data();
    return {
      success: true,
      date,
      allApproved,
      currentStreakDays: updated?.currentStreakDays ?? 0,
    };
  }
);
