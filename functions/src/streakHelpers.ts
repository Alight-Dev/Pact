//
// Shared helpers for opted-in streak logic.
// Day is "fully approved" when every (member × opted-in activity) has an approved submission.
//

import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();

export interface DayApprovalResult {
  allApproved: boolean;
  memberApproved: Map<string, boolean>;
}

/**
 * Returns whether the given day is fully approved for the team under opted-in semantics:
 * for every member, every activity in their opted-in set (or all goals if empty) must have
 * an approved submission for that date.
 */
export async function isDayFullyApproved(
  teamId: string,
  date: string
): Promise<DayApprovalResult> {
  const teamRef = db.collection("teams").doc(teamId);
  const membersSnap = await teamRef.collection("members").get();
  const goalsSnap = await teamRef.collection("goals").get();
  const goalIds = goalsSnap.docs.map((d) => d.id);

  const submissionsSnap = await teamRef
    .collection("dailyInstances")
    .doc(date)
    .collection("submissions")
    .get();

  const approvedSet = new Set<string>();
  for (const doc of submissionsSnap.docs) {
    const d = doc.data();
    const status = d.status as string;
    if (status === "approved" || status === "auto_approved") {
      const uid = d.submitterUid ?? doc.id.split("_")[0];
      const activityId = d.activityId ?? "";
      approvedSet.add(`${uid}_${activityId}`);
    }
  }

  const memberApproved = new Map<string, boolean>();
  let allApproved = true;

  for (const memberDoc of membersSnap.docs) {
    const uid = memberDoc.id;
    const member = memberDoc.data();
    const optedIn: string[] = member.optedInActivityIds ?? [];
    const requiredActivityIds =
      optedIn.length > 0 ? optedIn : goalIds;

    let memberOk = true;
    for (const activityId of requiredActivityIds) {
      if (!approvedSet.has(`${uid}_${activityId}`)) {
        memberOk = false;
        break;
      }
    }
    memberApproved.set(uid, memberOk);
    if (!memberOk) allApproved = false;
  }

  return { allApproved, memberApproved };
}
