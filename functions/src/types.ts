// Shared TypeScript types for Pact Cloud Functions.
// These mirror the Firestore data model in datamodel-updated.md.

export interface ActivityPayload {
  name: string;
  description: string;
  iconName: string;
  repeatDays: number[]; // 0 = Sun, 6 = Sat
  isOptional: boolean;
  order: number;
}

export type ShieldTier =
  | "bronze"
  | "iron"
  | "gold"
  | "shadow"
  | "crystal"
  | "emerald"
  | "platinum";

export type ShardStatus = "active" | "dimmed" | "cracked";

export type ForgeStatus = "pending_forge" | "active" | "paused" | "ended";

export type SubmissionStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "auto_approved";

// Shield tier thresholds (streak days → tier)
export const TIER_THRESHOLDS: { days: number; tier: ShieldTier }[] = [
  { days: 60, tier: "platinum" },
  { days: 45, tier: "emerald" },
  { days: 30, tier: "crystal" },
  { days: 21, tier: "shadow" },
  { days: 14, tier: "gold" },
  { days: 7,  tier: "iron" },
  { days: 0,  tier: "bronze" },
];

export function tierForStreak(days: number): ShieldTier {
  for (const { days: threshold, tier } of TIER_THRESHOLDS) {
    if (days >= threshold) return tier;
  }
  return "bronze";
}

export function dropTierOneLevel(current: ShieldTier): ShieldTier {
  const tiers: ShieldTier[] = [
    "bronze",
    "iron",
    "gold",
    "shadow",
    "crystal",
    "emerald",
    "platinum",
  ];
  const idx = tiers.indexOf(current);
  return idx > 0 ? tiers[idx - 1] : "bronze";
}

/** Returns today's date string "YYYY-MM-DD" in the given IANA timezone. */
export function todayInTimezone(timezone: string): string {
  return new Date().toLocaleDateString("en-CA", { timeZone: timezone });
}

/** Returns yesterday's date string "YYYY-MM-DD" in the given IANA timezone. */
export function yesterdayInTimezone(timezone: string): string {
  const now = new Date();
  now.setDate(now.getDate() - 1);
  return now.toLocaleDateString("en-CA", { timeZone: timezone });
}
