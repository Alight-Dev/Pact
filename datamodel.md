# Pact — Firebase Data Model

> **Philosophy:** Build the minimum that makes the core loop work. Every collection below is marked **MVP** (build now) or **Phase 2+** (designed for, build later). Phase 2+ fields are documented so the MVP schema doesn't need breaking changes when they're added.

---

## Core Loop (what the schema must support)

1. User signs in → profile saved
2. User creates or joins a team via invite code
3. Team admin defines a goal + "Forge Pact" agreement
4. Each day: member submits live photo → teammates vote → majority = approved → apps unlock
5. Daily cutoff: if all members approved → streak +1 → possibly tier up. If anyone missed → streak breaks → shard dims/cracks

---

## Collections Overview

```
users/{uid}
users/{uid}/teamMemberships/{teamId}      ← fan-out index
invites/{inviteCode}                      ← O(1) join-code lookup
teams/{teamId}
teams/{teamId}/members/{uid}
teams/{teamId}/goals/{goalId}
teams/{teamId}/goals/{goalId}/forgePactAgreements/{uid}
teams/{teamId}/dailyInstances/{date}
teams/{teamId}/dailyInstances/{date}/submissions/{uid}
teams/{teamId}/dailyInstances/{date}/submissions/{uid}/votes/{voterId}
teams/{teamId}/streakHistory/{date}       ← Phase 2
subscriptions/{uid}                       ← Phase 2
notifications/{notificationId}            ← Phase 2
```

---

## MVP Collections

### `users/{uid}`

Written at the end of onboarding (`OnboardingFlowView.profileSetup.onContinue`).

```
uid: string                   // = document ID = Firebase Auth UID
displayName: string           // from Google Sign-In (e.g. "John Doe")
nickname: string              // gamertag from OnboardingProfileSetupView
avatarID: number              // 0–49 index into the DiceBear pool
avatarAssetName: string       // "avatar_felix" — derived from avatarID
email: string | null          // null for anonymous users
fcmTokens: string[]           // updated on each app launch; supports multi-device
subscriptionTier: "free"      // "pro" added in Phase 2
isAnonymous: boolean
createdAt: Timestamp
updatedAt: Timestamp

// Onboarding survey data (stored for future personalization)
gender: string                // "Male" | "Female" | "Other"
ageRange: string              // "18–24" etc.
dailyScreenTime: string       // "1–3 hours" etc.
smartphoneYears: number
appCategories: string[]
```

---

### `users/{uid}/teamMemberships/{teamId}`

Fan-out index — written by `createTeam` / `joinTeam` Cloud Functions. Lets the home screen load all user's teams in a single collection read instead of scanning all teams.

```
teamId: string
teamName: string              // denormalized; update if team is renamed
role: "admin" | "member"
joinedAt: Timestamp
shardStatus: "active" | "dimmed" | "cracked"   // denormalized from member doc
shieldTier: string            // denormalized from team doc
currentStreakDays: number     // denormalized from team doc
```

---

### `invites/{inviteCode}`

Top-level collection so join-by-code is a single document read (`invites/847291`), no query needed.

> **Important:** `JoinShieldView.swift` enforces 6-digit numeric codes — use that format, not alphanumeric.

```
inviteCode: string            // = document ID, e.g. "847291"
teamId: string
teamName: string              // shown on join preview screen
adminNickname: string         // shown on join preview screen
memberCount: number           // enforced < maxMembers before join is allowed
maxMembers: number            // 5 (MVP hard limit)
createdAt: Timestamp
expiresAt: Timestamp | null   // null = never expires
isActive: boolean             // admin can deactivate; set false when team is full
```

---

### `teams/{teamId}`

Shield tier and streak are **embedded directly** on this document. Home screen reads one doc and gets everything — no subcollection reads needed for the header.

```
teamId: string
name: string
adminId: string               // uid of creator
inviteCode: string            // reference to /invites/{code}
memberCount: number           // 1–5; denormalized
maxMembers: number            // 5
createdAt: Timestamp
currentGoalId: string | null  // reference to /teams/{id}/goals/{goalId}
dailyCutoffUTC: number        // minutes from midnight UTC; default 0 (midnight)

// Shield & streak (embedded for zero-extra-read home screen)
shieldTier: "bronze" | "iron" | "gold" | "shadow" | "crystal" | "emerald" | "platinum"
currentStreakDays: number
lastStreakDate: string         // "YYYY-MM-DD"
bestStreakDays: number
streakComputedAt: Timestamp   // prevents double-computation by CF

// Today's live summary (updated by CF on each submission/approval)
todayApprovedCount: number
todayTotalMembers: number
todayDate: string             // "YYYY-MM-DD" — CF resets this each day
```

**Shield tier thresholds:**
| Tier | Streak days |
|------|-------------|
| Bronze | 0–6 |
| Iron | 7–13 |
| Gold | 14–20 |
| Shadow | 21–29 |
| Crystal | 30–44 |
| Emerald | 45–59 |
| Platinum | 60+ |

Tier drops 1 level (min Bronze) when streak breaks. Advances when `currentStreakDays` crosses the next threshold.

---

### `teams/{teamId}/members/{uid}`

One document per member. Holds shard state, role, and a copy of their display info so the member list renders without reading each user's doc.

```
userId: string
displayName: string           // denormalized from users/{uid}
nickname: string              // denormalized
avatarAssetName: string       // denormalized
role: "admin" | "member"
joinedAt: Timestamp
optedInActivityIds: string[]  // for optional activities (Phase 2)

// Shard state (updated by dailyStreakProcessor CF)
shardStatus: "active" | "dimmed" | "cracked"
consecutiveMisses: number     // 0 = active, 1 = dimmed, 2+ = cracked
lastApprovedDate: string | null   // "YYYY-MM-DD"
lastSubmissionDate: string | null

// FCM
fcmToken: string | null       // most recent token; used for targeted pushes from CF
```

---

### `teams/{teamId}/goals/{goalId}`

One active goal per team in MVP. Fields mirror `Activity.swift` exactly so writing from `ActivityListView` is direct.

```
goalId: string
teamId: string
name: string                  // mirrors Activity.name
description: string           // mirrors Activity.activityDescription
iconName: string              // SF Symbol — mirrors Activity.iconName
repeatDays: number[]          // [0..6] — mirrors Activity.repeatDays
isOptional: boolean           // mirrors Activity.isOptional
order: number
restrictedAppBundleIds: string[]   // chosen via FamilyControls picker
dailyDeadlineMinutesUTC: number   // inherits team default
forgeStatus: "pending_forge" | "active" | "paused" | "ended"

// Forge pact progress (denormalized so UI reads one doc)
agreedMemberIds: string[]     // CF appends uid on each agreement
agreedCount: number           // "3 of 5 agreed"

createdAt: Timestamp
activatedAt: Timestamp | null // set when forgeStatus → "active"
createdBy: string             // uid
```

---

### `teams/{teamId}/goals/{goalId}/forgePactAgreements/{uid}`

One document per member who tapped "Forge Pact". Document ID = `uid` so a member can only agree once (write fails if doc exists). Cloud Function (`onForgePactAgreement`) activates the goal when `agreedCount == memberCount`.

```
userId: string
displayName: string           // denormalized
nickname: string
agreedAt: Timestamp
```

---

### `teams/{teamId}/dailyInstances/{date}`

One document per team per calendar day (date = `"YYYY-MM-DD"` UTC). Created lazily on first submission by `onSubmissionCreated` CF.

```
teamId: string
date: string
goalId: string                // snapshot of active goal for this day
totalMembers: number          // snapshot of memberCount at day start
approvedCount: number         // incremented by CF on each approval
pendingCount: number          // decremented on approval/rejection
missedCount: number           // set by dailyStreakProcessor at cutoff
allApproved: boolean          // true when approvedCount == totalMembers
streakProcessed: boolean      // true after streak CF has run for this day
createdAt: Timestamp
cutoffAt: Timestamp
```

---

### `teams/{teamId}/dailyInstances/{date}/submissions/{uid}`

One per member per day. Document ID = submitter's `uid`.

Vote tallies (`approveCount`, `rejectCount`) are **denormalized** here and updated by Cloud Function via `FieldValue.increment` — the team feed can listen to a single doc instead of N vote docs.

Also queryable via `collectionGroup("submissions")` for cross-team queries (Phase 2 / Pro multi-team).

```
submissionId: string          // "{teamId}_{date}_{uid}" stored for collectionGroup use
teamId: string                // denormalized
date: string                  // denormalized
userId: string
displayName: string           // denormalized
avatarAssetName: string       // denormalized
photoURL: string              // short-lived signed URL (7-day); generated by CF
photoPath: string             // "proof-photos/{teamId}/{date}/{uid}.jpg" for deletion
submittedAt: Timestamp

// Status — written only by Cloud Functions (clients cannot write these)
status: "pending" | "approved" | "rejected" | "auto_approved"
approvalMethod: "peer_vote" | "ai_verified" | "auto_approve" | null
approvedAt: Timestamp | null
appUnlocked: boolean          // set true when approved; triggers app unlock on device

// Denormalized vote tallies (updated by onVoteCast CF)
voteCount: number
approveCount: number
rejectCount: number
eligibleVoterCount: number    // memberCount - 1

// AI/auto-approve scheduling
aiEligibleAt: Timestamp | null    // submittedAt + 2.5h (Phase 2)
autoApproveAt: Timestamp | null   // submittedAt + 6h (Phase 2)
```

---

### `teams/{teamId}/dailyInstances/{date}/submissions/{uid}/votes/{voterId}`

Document ID = `voterId`. This is the primary mechanism for two rules:
- **No double voting:** `allow create` only when the document doesn't already exist
- **No self-approval:** security rule enforces `voterId != submitterId`

Votes are **immutable** — no update or delete allowed.

```
voterId: string               // = document ID
vote: "approve" | "reject"
votedAt: Timestamp
voterNickname: string         // denormalized for vote history display
```

---

## Phase 2 Collections

These are designed now so the MVP schema doesn't need migration when they're added.

### `teams/{teamId}/streakHistory/{date}` *(Phase 2)*

Immutable daily log written by `dailyStreakProcessor`. Powers the analytics dashboard and milestone push notifications.

```
teamId: string
date: string
streakDayBefore: number
streakDayAfter: number
allApproved: boolean
approvedUserIds: string[]
missedUserIds: string[]
tierBefore: string
tierAfter: string
processedAt: Timestamp
```

---

### `subscriptions/{uid}` *(Phase 2)*

Written only by `validateSubscription` Cloud Function after receipt validation. Never written by the client.

```
userId: string
tier: "free" | "pro"
provider: "apple_iap" | "google_play" | "manual"
productId: string | null
purchasedAt: Timestamp | null
expiresAt: Timestamp | null   // null = lifetime
isActive: boolean
autoRenewing: boolean
```

**Free vs Pro:**
| Feature | Free | Pro |
|---------|------|-----|
| Teams | 1 | Unlimited |
| Shield tiers | Bronze–Gold only | All 7 tiers |
| AI verification | No | Yes |
| Analytics | No | Yes |
| Custom shard themes | No | Yes |

---

### `notifications/{notificationId}` *(Phase 2)*

In-app notification inbox. FCM payloads work without this in MVP — this collection is only needed when you build the notification center UI.

```
recipientUid: string
senderUid: string | null      // null for system/CF notifications
teamId: string
type: "vote_needed" | "submission_approved" | "submission_rejected" |
      "streak_milestone" | "teammate_submitted" | "daily_reminder" |
      "forge_pact_ready" | "teammate_joined"
title: string
body: string
data: map                     // passed through to FCM data payload
sentAt: Timestamp
readAt: Timestamp | null
fcmMessageId: string | null   // for deduplication
```

---

## Cloud Functions

### MVP (build these first)

| # | Name | Trigger | What it does |
|---|------|---------|--------------|
| CF-1 | `onVoteCast` | Firestore onCreate — votes | Increment `approveCount`/`rejectCount`; check majority; if approved → set `status`, `appUnlocked`, update `dailyInstances` counts, update member's `lastApprovedDate`, reset shard to active; FCM to submitter |
| CF-2 | `onSubmissionCreated` | Firestore onCreate — submissions | Lazily create `dailyInstances` doc; increment `pendingCount`; enqueue auto-approve task at +6h; FCM "vote needed" to teammates |
| CF-3 | `onForgePactAgreement` | Firestore onCreate — forgePactAgreements | Increment `agreedCount`; if `agreedCount == memberCount` → set `forgeStatus = "active"`; FCM to all members |
| CF-6 | `dailyStreakProcessor` | Cloud Scheduler at daily cutoff | For each active team: increment/break streak; update shard states; update shield tier; fan-out to `teamMemberships`; create next day's `dailyInstances` |
| CF-7 | `joinTeam` | HTTP Callable | Validate invite code; atomic batch: create `members` doc + increment `memberCount` + create `teamMemberships` doc |
| CF-8 | `createTeam` | HTTP Callable | Generate unique 6-digit code; batch: create team + member + invite + teamMembership; write goals from `ActivityListView` |

### Phase 2

| # | Name | Trigger | What it does |
|---|------|---------|--------------|
| CF-4 | `aiVerificationCheck` | Cloud Tasks at `submittedAt + 2.5h` | If still pending: call Claude Vision / GPT-4o; if confident → approve with `approvalMethod = "ai_verified"` |
| CF-5 | `autoApproveSubmission` | Cloud Tasks at `submittedAt + 6h` | If still pending → `status = "auto_approved"` with visible note |
| CF-9 | `validateSubscription` | HTTP Callable | Validate Apple/Google receipt; write `subscriptions/{uid}`; update `subscriptionTier` |
| CF-10 | `sendDailyReminders` | Cloud Scheduler | FCM to members who haven't submitted today |
| CF-11 | `archiveOldData` | Cloud Scheduler weekly | Delete `dailyInstances` + `submissions` + `votes` older than 90 days; delete Storage files |

---

## Storage

**Path structure:**
```
proof-photos/{teamId}/{date}/{uid}.jpg
// e.g. proof-photos/abc123/2026-02-26/userXYZ.jpg
```

- `{teamId}/{date}/` prefix → batch deletion by date for 90-day TTL
- `{uid}.jpg` is deterministic → re-upload overwrites without orphaned files
- iOS client converts camera capture to JPEG before upload

**Access pattern:**
- Client uploads directly to Storage (Storage rule: `request.auth.uid == uid`, size < 10MB, image content type)
- `onSubmissionCreated` CF generates a 7-day signed URL and writes it to `submissions.photoURL`
- Clients read the photo via `photoURL` from Firestore — never read Storage directly
- `photoPath` stored on submission doc for Admin SDK deletion when team is deleted or TTL expires

---

## Security Rules (strategy)

**Self-approval** — enforced at data layer in the vote security rule:
```javascript
allow create: if ... && voterId != submitterId
```

**Double-voting** — enforced at data layer by document ID:
```javascript
// voterId IS the document ID. create is only allowed when doc doesn't exist.
allow create: if ... && !exists(/.../votes/$(voterId))
```

**Computed fields clients cannot write** (status, approveCount, shieldTier, appUnlocked, currentStreakDays, etc.) — blocked in rules; only Cloud Functions with Admin SDK bypass rules.

**Membership enforcement** — all team subcollection reads require:
```javascript
function isTeamMember(teamId) {
  return exists(/databases/.../teams/$(teamId)/members/$(request.auth.uid));
}
```

---

## Composite Indexes Needed

| Collection | Fields | Used for |
|---|---|---|
| `submissions` (collectionGroup) | `teamId ASC, date DESC, status ASC` | Team feed filtered by status |
| `submissions` (collectionGroup) | `userId ASC, date DESC` | User's own history |
| `teams/{id}/dailyInstances/{date}/submissions` | `status ASC, submittedAt DESC` | Pending queue today |
| `notifications` | `recipientUid ASC, sentAt DESC` | Notification inbox (Phase 2) |
| `teams/{id}/streakHistory` | `date DESC` | Streak chart (Phase 2) |

---

## Key Implementation Notes

1. **Write user profile in `OnboardingFlowView`** — at `profileSetup.onContinue`, write all collected fields (`selectedGender`, `selectedAge`, `selectedScreenTime`, `smartphoneYears`, `selectedCategories`, `profileNickname`, `profileAvatarID`) to `users/{uid}`.

2. **`ActivityListView` → `createTeam` CF** — the activities defined in `ActivityListView` map 1:1 to `goals/{goalId}` documents. Pass the full array to `CF-8`.

3. **`pact://join/{inviteCode}` deep link** — `PactApp.swift`'s `.onOpenURL` currently handles Google Sign-In redirects. Extend it to also detect `pact://join/` scheme and call `CF-7 joinTeam`.

4. **`appUnlocked` flag** — the iOS app observes this field via a Firestore real-time listener. When it flips to `true`, the app calls `ManagedSettings` to remove the app restriction for that user.

5. **Invite code format** — `JoinShieldView.swift` enforces 6-digit numeric codes. `CF-8` must generate codes in this format and check for collisions in `/invites`.
