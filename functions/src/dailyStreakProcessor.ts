// CF-6: dailyStreakProcessor — Cloud Scheduler (runs hourly)
//
// For each active team, checks if it is now past that team's cutoff time
// (based on adminTimezone). Processes yesterday's dailyInstance:
//  - allApproved → streak +1, possible tier upgrade
//  - otherwise   → streak reset, shard dim/crack for missed members
// Fans out updated shieldTier / streakDays / shardStatus to teamMemberships.
// Proactively creates today's dailyInstance doc.

import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import {
  tierForStreak,
  dropTierOneLevel,
  yesterdayInTimezone,
  todayInTimezone,
} from "./types";

const db = getFirestore();

export const dailyStreakProcessor = onSchedule(
  {
    schedule: "0 * * * *", // Every hour; function checks timezone internally
    region: "us-central1",
    timeoutSeconds: 300,
  },
  async () => {
    const teamsSnap = await db.collection("teams").get();
    const now = Timestamp.now();

    await Promise.all(
      teamsSnap.docs.map((teamDoc) => processTeam(teamDoc.id, teamDoc.data(), now))
    );
  }
);

async function processTeam(
  teamId: string,
  teamData: FirebaseFirestore.DocumentData,
  now: Timestamp
): Promise<void> {
  const timezone: string = teamData.adminTimezone ?? "UTC";
  const yesterday = yesterdayInTimezone(timezone);
  const today = todayInTimezone(timezone);

  const instanceRef = db
    .collection("teams").doc(teamId)
    .collection("dailyInstances").doc(yesterday);
  const instanceSnap = await instanceRef.get();

  // Skip if instance doesn't exist or already processed
  if (!instanceSnap.exists) return;
  const instance = instanceSnap.data()!;
  if (instance.streakProcessed) return;

  // Mark processed immediately to prevent double-runs
  await instanceRef.update({ streakProcessed: true });

  const allApproved: boolean = instance.allApproved ?? false;
  const currentStreak: number = teamData.currentStreakDays ?? 0;
  const currentTier: string = teamData.shieldTier ?? "bronze";

  let newStreak: number;
  let newTier: string;

  if (allApproved) {
    newStreak = currentStreak + 1;
    newTier = tierForStreak(newStreak);
  } else {
    newStreak = 0;
    newTier = dropTierOneLevel(currentTier as any);
  }

  const teamRef = db.collection("teams").doc(teamId);

  // Update team streak + tier
  await teamRef.update({
    currentStreakDays: newStreak,
    lastStreakDate: yesterday,
    bestStreakDays: Math.max(teamData.bestStreakDays ?? 0, newStreak),
    shieldTier: newTier,
    streakComputedAt: now,
    // Reset today's counters
    todayApprovedCount: 0,
    todayDate: today,
  });

  // Update each member's shard status
  const membersSnap = await teamRef.collection("members").get();

  await Promise.all(
    membersSnap.docs.map(async (memberDoc) => {
      const member = memberDoc.data();
      const uid: string = memberDoc.id;

      let shardStatus: string = member.shardStatus ?? "active";
      let consecutiveMisses: number = member.consecutiveMisses ?? 0;

      if (allApproved) {
        // Everyone approved — reset shard to active for this member
        shardStatus = "active";
        consecutiveMisses = 0;
      } else {
        // Per-activity: member is "approved" for the day if they have all required submissions approved
        const submissionsSnap = await db
          .collection("teams").doc(teamId)
          .collection("dailyInstances").doc(yesterday)
          .collection("submissions")
          .get();
        const goalsSnap = await teamRef.collection("goals").get();
        const expectedCount = goalsSnap.size;
        const memberApprovedSubmissions = submissionsSnap.docs.filter(
          (d) => (d.data().submitterUid === uid || d.id.startsWith(uid + "_"))
            && (d.data().status === "approved" || d.data().status === "auto_approved")
        );
        const memberApproved = expectedCount > 0 && memberApprovedSubmissions.length >= expectedCount;

        if (!memberApproved) {
          consecutiveMisses += 1;
          shardStatus =
            consecutiveMisses >= 2 ? "cracked" : "dimmed";
        } else {
          consecutiveMisses = 0;
          shardStatus = "active";
        }
      }

      await memberDoc.ref.update({
        shardStatus,
        consecutiveMisses,
      });

      // Fan-out to teamMemberships
      await db
        .collection("users").doc(uid)
        .collection("teamMemberships").doc(teamId)
        .update({
          shardStatus,
          shieldTier: newTier,
          currentStreakDays: newStreak,
        });
    })
  );

  // Proactively create today's dailyInstance if it doesn't exist yet
  const todayRef = teamRef.collection("dailyInstances").doc(today);
  const todaySnap = await todayRef.get();
  if (!todaySnap.exists) {
    const goalsSnap = await teamRef.collection("goals").get();
    const activityCount = goalsSnap.size;
    const totalMembers: number = teamData.memberCount ?? 1;
    const expectedSubmissionCount = totalMembers * Math.max(activityCount, 1);

    await todayRef.set({
      teamId,
      date: today,
      goalId: teamData.currentGoalId ?? null,
      totalMembers,
      expectedSubmissionCount,
      approvedCount: 0,
      pendingCount: 0,
      missedCount: 0,
      allApproved: false,
      streakProcessed: false,
      createdAt: now,
      cutoffAt: Timestamp.fromDate(new Date(`${today}T23:59:59Z`)),
    });
  }
}
