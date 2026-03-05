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
import { isDayFullyApproved } from "./streakHelpers";

const db = getFirestore();

/** Options when processing a date for streak (e.g. from onVoteCast when today becomes complete). */
export interface ProcessDateOptions {
  /** If true, reset todayApprovedCount and todayDate on the team doc (set when scheduler processes yesterday). Default true. */
  resetTodayCounters?: boolean;
  /** When resetTodayCounters is true, the team doc's todayDate is set to this (e.g. today in team timezone). */
  today?: string;
  /** If true, run even when instance.streakProcessed is already true (re-apply team/member updates only; do not set streakProcessed). */
  force?: boolean;
}

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

/**
 * Processes a single date for streak: updates team currentStreakDays/shieldTier,
 * member shards, and teamMemberships. Call from scheduler (for yesterday) or from
 * onVoteCast when the current day becomes allApproved (so the UI updates immediately).
 */
export async function processDateForStreak(
  teamId: string,
  date: string,
  teamData: FirebaseFirestore.DocumentData,
  now: Timestamp,
  options: ProcessDateOptions = {}
): Promise<void> {
  const { resetTodayCounters = true, force = false } = options;
  const teamRef = db.collection("teams").doc(teamId);
  const instanceRef = teamRef.collection("dailyInstances").doc(date);
  const instanceSnap = await instanceRef.get();

  if (!instanceSnap.exists) return;
  const instance = instanceSnap.data()!;
  if (instance.streakProcessed && !force) return;

  if (!force) {
    await instanceRef.update({ streakProcessed: true });
  }

  const { allApproved, memberApproved } = await isDayFullyApproved(teamId, date);
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

  const updateData: Record<string, unknown> = {
    currentStreakDays: newStreak,
    lastStreakDate: date,
    bestStreakDays: Math.max(teamData.bestStreakDays ?? 0, newStreak),
    shieldTier: newTier,
    streakComputedAt: now,
  };
  if (resetTodayCounters && options.today != null) {
    updateData.todayApprovedCount = 0;
    updateData.todayDate = options.today;
  }
  await teamRef.update(updateData);

  const membersSnap = await teamRef.collection("members").get();
  await Promise.all(
    membersSnap.docs.map(async (memberDoc) => {
      const member = memberDoc.data();
      const uid: string = memberDoc.id;

      let shardStatus: string = member.shardStatus ?? "active";
      let consecutiveMisses: number = member.consecutiveMisses ?? 0;

      if (allApproved) {
        shardStatus = "active";
        consecutiveMisses = 0;
      } else {
        const memberOk = memberApproved.get(uid) ?? false;
        if (!memberOk) {
          consecutiveMisses += 1;
          shardStatus = consecutiveMisses >= 2 ? "cracked" : "dimmed";
        } else {
          consecutiveMisses = 0;
          shardStatus = "active";
        }
      }

      await memberDoc.ref.update({ shardStatus, consecutiveMisses });
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
}

async function processTeam(
  teamId: string,
  teamData: FirebaseFirestore.DocumentData,
  now: Timestamp
): Promise<void> {
  const timezone: string = teamData.adminTimezone ?? "UTC";
  const yesterday = yesterdayInTimezone(timezone);
  const today = todayInTimezone(timezone);

  await processDateForStreak(teamId, yesterday, teamData, now, {
    resetTodayCounters: true,
    today,
  });

  const teamRef = db.collection("teams").doc(teamId);
  const membersSnap = await teamRef.collection("members").get();

  // Proactively create today's dailyInstance if it doesn't exist yet
  const todayRef = teamRef.collection("dailyInstances").doc(today);
  const todaySnap = await todayRef.get();
  if (!todaySnap.exists) {
    const goalsSnap = await teamRef.collection("goals").get();
    const goalIds = goalsSnap.docs.map((d) => d.id);
    const expectedSubmissionCount = membersSnap.docs.reduce((sum, doc) => {
      const optedIn: string[] = doc.data().optedInActivityIds ?? [];
      const count = optedIn.length > 0 ? optedIn.length : Math.max(goalIds.length, 1);
      return sum + count;
    }, 0);

    await todayRef.set({
      teamId,
      date: today,
      goalId: teamData.currentGoalId ?? null,
      totalMembers: membersSnap.size,
      expectedSubmissionCount: Math.max(expectedSubmissionCount, 1),
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
