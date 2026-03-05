# Pact — MVP Feature Checklist

> **How to use this file:**
> - When a feature is completed, change `[ ]` to `[x]`.
> - Run an incremental scan of the codebase before starting any session to verify this list is accurate.
> - If you discover a feature is already implemented during a scan, check it off immediately.
> - Add new items to the relevant section whenever a new requirement is identified.

---

## 1. Authentication

- [x] Firebase Auth setup and `AuthManager` observable
- [x] Google Sign-In implemented (`AuthManager.signInWithGoogle`)
- [x] Auth state listener (auto-detects sign-in/sign-out)
- [x] Apple Sign-In implementation — `signInWithApple()` via `AppleSignInHandler` delegate bridge, `deleteAccountWithApple()` with token revocation (App Store 5.1.1(v)), `providerID` computed property, Apple-aware `signOut()`; entitlement added to `Pact.entitlements`; button enabled in `OnboardingSignupView` above Google per HIG
- [x] Save full user profile to Firestore (`users/{uid}`) at end of onboarding (`OnboardingProfileSetupView.onContinue` → `FirestoreService.saveUserProfile`)
- [x] Session restore on app launch: if user is already signed in and has an active team, load membership (`loadActiveMembership`), start listeners (`startTeamSession`), and route directly to `HomeScreenView` — skipping onboarding and shield selection

---

## 2. Onboarding Flow

- [x] Splash screen (`SplashView`) with "Get Started" CTA
- [x] Onboarding step coordinator (`OnboardingFlowView`)
- [x] Step 1 — Gender selection (`OnboardingGenderView`)
- [x] Step 2 — Age selection (`OnboardingAgeView`)
- [x] Step 3 — Daily screen time estimate (`OnboardingScreenTimeView`)
- [x] Step 4 — Projection inputs: years + app category (`OnboardingProjectionInputsView`)
- [x] Step 5 — Animated projection results (`OnboardingProjectionView`)
- [x] Step 6 — Notification permission request (`OnboardingRequestNotificationsView`)
- [x] Step 7 — Sign-in screen UI (`OnboardingSignupView`)
- [x] Step 8 — Profile setup: gamertag + avatar (`OnboardingProfileSetupView`)
- [x] Post-onboarding: Create or Join Shield selection (`OnboardingCreateOrJoinShieldView`)
- [x] Screen Time access intro screen (`OnboardingScreenTimeAccessIntroView`)
- [x] Screen Time access approved screen (`OnboardingScreenTimeApprovedView`)

---

## 3. Team Creation

- [x] Team name entry screen (`OnboardingTeamNameView`)
- [x] Activity/goal definition screen (`ActivityListView`)
- [x] `FirestoreService.createTeam` (calls CF-8)
- [x] Wire `ActivityListView` "Continue" button to call `FirestoreService.createTeam`
- [x] Show invite code after team creation — `TeamWelcomeView` presents invite code with copy button + optional "Share Invite" sheet; user can skip directly to app with "Go to Pact" (replaces forced `UIActivityViewController`)
- [x] Add "Share Invite" button to `TeamView` so admin can re-share the invite code at any time (`ShareLink` in `ShieldMembersSection` reads `inviteShareURL` from live Firestore or UserDefaults cache)
- [ ] Wire `minApprovers` and `allowAIFallback` from `ActivityListView` "Initial Conditions" card into the `createTeam` Cloud Function payload (requires CF update too)
- [ ] Deduplicate SwiftData activities before calling `createTeam` if navigation ever allows re-entry to `ActivityListView` (defensive guard)
- [ ] `FamilyActivityPicker` integration in `ActivityListView` (admin selects which apps to restrict; store serialized selection in goal doc)

---

## 4. Joining a Team

- [x] Join Shield screen with 6-digit code entry (`JoinShieldView`)
- [x] `FirestoreService.joinTeam` (calls CF-7)
- [x] Deep link handling (`pact://join/{inviteCode}` in `PactApp.onOpenURL`)
- [ ] Team preview screen before confirming join (show team name, admin nickname, member count from `/invites/{code}`)
- [x] After joining: start team session and route to `HomeScreenView`

---

## 5. Forge Pact Agreement

- [x] `FirestoreService.forgePact` (writes `forgePactAgreements/{uid}` doc)
- [ ] "Forge Pact" UI screen: show current goal details and a large "Forge Pact" CTA button
- [ ] Show agreement progress: "X of Y members agreed" (listen to `goals/{goalId}.agreedCount`)
- [ ] Disable/hide "Forge Pact" button once user has already agreed
- [ ] Notify team when all members agreed and goal becomes active (handled by CF-3 FCM push)
- [ ] Route newly created teams to the Forge Pact screen before showing `HomeScreenView`

---

## 6. Home Screen (`HomeView`)

- [x] UI shell: header with nickname/avatar, progress ring, carousel cards, today's goal card
- [x] Profile sheet trigger from avatar tap
- [ ] Wire progress ring to today's approved / total activities ratio (replace hardcoded `ringProgress = 0.35`)
- [ ] Wire Health Score card to real weekly streak data from Firestore (replace placeholder text and `4/5`)
- [ ] Wire Team Progress card avatars to real `FirestoreService.members` (replace `teamAvatars` mock array)
- [x] Wire "Today's Goal" activity list to `FirestoreService.teamActivities` (joiner now sees real activities; falls back to SwiftData for admin mid-onboarding)
- [x] Wire "Today's Goal" card completion status to `FirestoreService.todaysSubmissions` (`myCompletedActivityIds` / `myCompletedActivityNames` filter `mappedSubmissions` by uid + approved status; rows show checkmark per activity)
- [x] Wire "Your Completion" counter and progress bar to real approved submission count (`completedCount` / `totalActivities` in `HomeView.todayGoalCard`)
- [ ] Show today's goal name from Firestore (`currentTeam["currentGoalId"]` → goal doc)
- [ ] "Complete Today's Task" CTA button that opens the live camera / `UploadView`
- [ ] Show lock/unlock status indicator (locked until today's submission is approved)

---

## 7. Proof Submission (`UploadView`)

- [x] Replace stub with live camera capture view (AVFoundation; no photo library access) — `CameraScreen.swift` with `CameraViewModel` + `AVCaptureSession`
- [x] Enforce live camera only — no photo library picker; `UploadProofView` only renders `CameraScreen`
- [x] Preview captured photo before submission — `ConfirmPhotoView` full-screen dark review screen
- [x] Upload photo to Firebase Storage (`proof/{teamId}/{date}/{uid}_{activityId}.jpg`) — `FirestoreService.submitProof`
- [x] Create submission document in Firestore (doc ID `{uid}_{activityId}`; triggers CF-2: `onSubmissionCreated`) — `FirestoreService.submitProof`
- [ ] Show submission status after submit: pending / approved / rejected / auto-approved (Home screen should show "Proof pending" badge if today's submission is in `pending` status)
- [x] Prevent re-submission per activity (check `mappedSubmissions` for existing submission for same `activityId` + uid today; show error in `ConfirmPhotoView` instead of submitting)
- [ ] "Complete Today's Task" CTA on `HomeView` todayGoalCard that opens `UploadProofView` fullScreenCover (currently card is display-only)

---

## 8. Team Feed & Voting (`TeamView`)

- [x] Swipeable pending-approval card stack UI (`SubmissionCard`, `SwipeableCardStack`)
- [x] Approve/Reject buttons and swipe gestures on cards
- [x] Highlights section for approved submissions (carousel)
- [x] Shield members list with progress bars
- [x] Replace mock submissions with real `FirestoreService.mappedSubmissions` (real-time) — `pendingSubmissions` and `approvedSubmissions` both derived from live listener
- [x] Replace mock members with real `FirestoreService.members` (real-time; falls back to mock on first render)
- [x] Wire "Approve"/"Reject" swipe and button actions to `FirestoreService.castVote` — `TeamView.handleVote` calls `castVote`
- [x] Show actual proof photo from `submission.photoURL` in vote card — `CachedProofImage(urlString: submission.photoUrl)` in both `SubmissionCard` and `HighlightCard`
- [x] Hide vote actions on the current user's own submission (no self-approval) — `refreshPending` filters `sub.submitterUid != currentUid`
- [x] Disable vote buttons after user has already voted on a submission — `refreshPending` checks `votedSubmissionIds` (in-session) and `sub.voterIds` (Firestore-backed)
- [x] Wire team name, shield tier, and streak counter in `TeamShieldHeader` to real Firestore data — `shieldDisplayName`, `ShieldTier.current(for: streakDays)`, and `streakDays` all read from `firestoreService.currentTeam`
- [x] Replace hardcoded "Morning Forge Alliance" team description and "Emerald Tier / 12 day streak" with live data — fully live via `TeamShieldHeader` params

---

## 9. App Locking — Screen Time API

> Requires a physical device with the Family Controls entitlement. Cannot be tested in Simulator.

- [ ] Request `FamilyControls` authorization during onboarding (Screen Time access screens exist; authorization call needs wiring)
- [ ] Admin: present `FamilyActivityPicker` to select apps to restrict; serialize and store `FamilyActivitySelection` in `goals/{goalId}.familyActivitySelection`
- [ ] Member: restore `FamilyActivitySelection` from Firestore and apply via `ManagedSettings` store
- [ ] Create `DeviceActivity` app extension target for scheduling the daily morning lock cycle
- [ ] Apply restrictions (`ManagedSettingsStore`) at team daily cutoff each morning
- [ ] Create Shield Activation Extension (custom blocking screen shown when a locked app is tapped — displays Pact logo and "Complete today's task to unlock")
- [ ] Listen to `members/{uid}.lockShieldActive` via Firestore real-time listener; apply restrictions on app launch/device reboot
- [ ] Listen to `submissions/{uid}.appUnlocked` via Firestore real-time listener; remove restrictions immediately on approval

---

## 10. Shield Progression Visuals

- [ ] Design and implement the gem-forged hexagonal shield component (team shield composed of individual member shards)
- [ ] Shard states per member: `active` (bright/glowing), `dimmed` (muted), `cracked` (visually fractured)
- [ ] Shield tier visual differentiation across all 7 tiers: Bronze → Iron → Gold → Shadow → Crystal → Emerald → Platinum
- [ ] Show real shield tier label and tier color in `TeamShieldHeader`
- [ ] Shield tier upgrade animation / celebration when streak milestone is hit
- [ ] Streak milestone labels corresponding to tier thresholds (7 / 14 / 21 / 30 / 45 / 60 days)

---

## 11. Push Notifications (FCM)

- [x] FCM token registration and storage in Firestore (`updateFCMToken`)
- [x] FCM token refresh on sign-in
- [ ] Handle incoming FCM push notification payload in `PactApp` (foreground + background)
- [ ] Route notification taps to the correct screen: vote_needed → TeamView, submission_approved → HomeView, etc.
- [ ] Request notification permission during onboarding (screen exists; needs to be called before FCM token retrieval)

---

## 12. Home Screen Widget (WidgetKit)

- [ ] Create `WidgetKit` extension target in Xcode (`PactWidget`)
- [ ] Widget shows: shield fragment, current tier, streak counter, daily completion status (X/N forged), lock/unlock badge
- [ ] Use `AppGroup` shared `UserDefaults` (or Firestore snapshot) to pass data from app to widget
- [ ] Add widget to App Store listing metadata

---

## 13. Cloud Functions

- [x] CF-1 `onVoteCast` — vote aggregation, majority check, app unlock, FCM to submitter (TypeScript written)
- [x] CF-2 `onSubmissionCreated` — lazily create `dailyInstances` doc, FCM "vote needed" to teammates (TypeScript written)
- [x] CF-3 `onForgePactAgreement` — increment agreed count, activate goal when all agreed, FCM to team (TypeScript written)
- [x] CF-6 `dailyStreakProcessor` — Cloud Scheduler: streak increment/break, shard states, tier upgrade, fan-out (TypeScript written)
- [x] CF-7 `joinTeam` — validate code, atomic batch join, update eligibleVoterCount (TypeScript written)
- [x] CF-8 `createTeam` — generate invite code, batch create team/member/invite/membership, write goals (TypeScript written)
- [ ] Deploy all MVP Cloud Functions to Firebase (`firebase deploy --only functions`)
- [ ] Smoke-test each Cloud Function in staging environment
- [ ] Configure Cloud Scheduler trigger for CF-6 (`dailyStreakProcessor`)

---

## 14. Firebase Backend Configuration

- [ ] Deploy Firestore security rules (`firebase deploy --only firestore:rules`)
- [ ] Create required composite Firestore indexes (`firebase deploy --only firestore:indexes`)
- [ ] Configure GCS Object Lifecycle Management: auto-delete `proof-photos/` objects older than 30 days
- [ ] Verify `GoogleService-Info.plist` is present and correctly configured for the app bundle ID
- [ ] Enable Firebase Storage in Firebase Console and set storage rules
- [ ] Configure FCM in Firebase Console (APNs certificate/key uploaded)

---

## 15. Invite & Sharing

- [x] After team creation: present invite code with optional share — `TeamWelcomeView` shows 6-digit code (copyable), "Share Invite" opens iOS share sheet with link, "Go to Pact" skips directly to app
- [x] "Invite more members" button on `TeamView` (copies or shares invite link) — `ShareLink` in `ShieldMembersSection`
- [x] Show invite code in team settings or a dedicated invite screen — invite URL surfaced via `TeamView` share button

---

## 16. Profile Screen

- [ ] Wire `ProfileView` to display real user data from Firestore (`displayName`, `nickname`, `avatarAssetName`, `currentStreakDays`) — currently reads from `UserDefaults` only
- [x] Sign out button functional — `ProfileView` calls `authManager.signOut()`; `signOut()` is provider-aware (only calls `GIDSignIn.sharedInstance.signOut()` for Google; Firebase signOut covers Apple)
- [ ] Show which team(s) the user belongs to

---

## 17. Code Quality & Polish

- [ ] Remove unused placeholder files: `ContentView.swift`, `Item.swift`
- [ ] Error handling and user-facing error messages throughout (auth failures, network errors, Firestore write failures)
- [ ] Loading states (skeletons or `ProgressView`) on all async data loads
- [ ] Empty-state views: no team yet, no submissions today, no pending votes
- [ ] App icon finalized (all required sizes)
- [ ] Launch screen / `Info.plist` URL scheme (`pact`) registered for deep links
- [ ] Accessibility: minimum tap targets, VoiceOver labels on icon-only buttons
- [ ] Confirm `Info.plist` contains `NSCameraUsageDescription` for live camera access
- [ ] Confirm `Info.plist` contains Family Controls entitlement reference for TestFlight/App Store builds

---

## Completed Items Archive

> Move checked-off items here periodically to keep the active list readable.

*(none yet)*
