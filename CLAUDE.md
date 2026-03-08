# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Keeping This File Updated

This file should evolve with the project. Whenever a meaningful feature is added, an architectural decision is made, a new dependency is integrated, or the product vision shifts, update the relevant section here. The goal is for this file to always reflect the current state of the codebase accurately — not a snapshot from early development.

## MVP Feature Tracking — TODO.md

All MVP features and their completion status are tracked in **[`TODO.md`](./TODO.md)**.

### Rules for Claude when working on this project:

1. **Incremental scan before starting work:** At the beginning of every coding session (or whenever asked), scan the relevant Swift source files and Cloud Function TypeScript files to check whether any `TODO.md` items have been completed since the last update. Check off any completed items you discover.
2. **Check off on completion:** Immediately after implementing a feature or wiring a piece of functionality, open `TODO.md` and change the corresponding `[ ]` to `[x]`. Do this before moving on to the next task.
3. **Add new items:** If you discover a new requirement or sub-task not currently listed, add it to the appropriate section in `TODO.md` before starting work on it.
4. **Move completed items:** Periodically move large groups of completed (`[x]`) items to the "Completed Items Archive" section at the bottom of `TODO.md` to keep the active list readable.

## Build & Run

Open in Xcode and run with ⌘R (select your connected iPhone as the run destination in the scheme toolbar), or from the terminal:

```bash
open Pact.xcodeproj
```

To build for a **connected iPhone** (device plugged in):

```bash
xcodebuild -scheme Pact -destination 'generic/platform=iOS' build
```

To run on the connected device from the command line, use the device name or ID. List connected devices:

```bash
xcrun xctrace list devices
```

Then build and run (replace `Your iPhone` with your device name from the list, or use `id=UDID`):

```bash
xcodebuild -scheme Pact -destination 'platform=iOS,name=Your iPhone' build
```

To run tests (use simulator for tests unless you need device-only APIs):

```bash
xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16' test
```

To run a single test class:

```bash
xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PactTests/PactTests test
```

**Simulator build** (if you need to build for simulator instead):

```bash
xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16' build
```

> Features using `FamilyControls` and `ManagedSettings` (app blocking) require a **physical device** with a provisioning profile that includes the Family Controls entitlement. They cannot be tested in the simulator.

> **Device signing & bundle ID:** Copy `Config/Development.xcconfig.example` to `Config/Development.xcconfig` and set `DEVELOPMENT_TEAM` and optionally `BUNDLE_ID_PREFIX` (e.g. `cmc` or `com.chris`) so each developer can run on device with their own bundle ID without changing the project file.

## Project Details

- **Language:** Swift 5.0
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **iOS Deployment Target:** 26.2
- **Bundle ID:** Set via `BUNDLE_ID_PREFIX` in `Config/Development.xcconfig` (default from example: `cmc.Pact`).

## Architecture

See [`pages.md`](./pages.md) for a full per-screen breakdown. Below is the high-level file map.

### App Entry

- **`PactApp.swift`** — App entry point. Handles session restore (signed-in users skip onboarding), deep-link routing (`pact://join/{code}`), forge-pact routing, and name-confirmation routing after sign-up. Injects `AuthManager`, `FirestoreService`, and `NotificationRouter` as environment objects. Initializes the SwiftData `ModelContainer`.
- **`AppDelegate.swift`** — `UIApplicationDelegate` + `UNUserNotificationCenterDelegate` + `MessagingDelegate`. Intercepts foreground/background FCM push notifications and posts to `NotificationCenter`. Handles FCM token refresh.
- **`SplashView.swift`** — Animated splash screen with spring-animated logo. "Get Started" transitions to onboarding.
- **`HomeScreenView.swift`** — Root tab container. Owns `selectedTab` state; renders `HomeView`, `UploadView`, or `TeamView`. Contains `FloatingTabBar` — liquid-glass pill with Home, Upload (+), and Team tabs.

### Onboarding

- **`Onboarding/OnboardingFlowView.swift`** — Step coordinator for the 8-step onboarding sequence (`OnboardingStep` enum, slide transitions).
- **`Onboarding/OnboardingGenderView.swift`** — Step 1/8. Gender selection (selectable pills).
- **`Onboarding/OnboardingAgeView.swift`** — Step 2/8. Age range selection.
- **`Onboarding/OnboardingScreenTimeView.swift`** — Step 3/8. Daily screen time estimate.
- **`Onboarding/OnboardingProjectionInputsView.swift`** — Step 4/8. Slider for years with smartphone + app category selection.
- **`Onboarding/OnboardingLoadingView.swift`** — Transient loading screen between ProjectionInputs and ProjectionView. 5 pulsing dots; auto-advances after ~2.2 s. Not a numbered step.
- **`Onboarding/OnboardingProjectionView.swift`** — Step 5/8. Animated display of projected lifetime screen time and days to reclaim.
- **`Onboarding/OnboardingRequestNotificationsView.swift`** — Step 6/8. Social notification preview; requests iOS push permission via `UNUserNotificationCenter`.
- **`Onboarding/OnboardingSignupView.swift`** — Step 7/8. "Continue with Apple" / "Continue with Google" sign-in. Logo animates to upper-middle.
- **`Onboarding/OnboardingNameConfirmationView.swift`** — Shown immediately after sign-up (outside the 8-step flow). Pre-fills name from Auth provider; user can edit. Back signs out and returns to splash.
- **`Onboarding/OnboardingProfileSetupView.swift`** — Step 8/8. Gamertag (Xbox-style generator + manual) and avatar picker (4×3 grid + full sheet).
- **`Onboarding/OnboardingScreenTimeAccessIntroView.swift`** — Explains Screen Time / FamilyControls before triggering authorization.
- **`Onboarding/OnboardingScreenTimeApprovedView.swift`** — Confirmation screen shown after Screen Time access is granted.
- **`Onboarding/OnboardingCreateOrJoinSheildView.swift`** — Post-onboarding: "Create a Shield" or "Join a Shield" selection. *(Note: filename has a typo — "Sheild".)*
- **`Onboarding/OnboardingComponents.swift`** — Shared onboarding UI components: `SelectablePillButton`, `OnboardingProgressBar`.

### Team Creation & Join

- **`Onboarding/OnboardingTeamNameView.swift`** — Team name entry screen (first step of create-shield flow).
- **`ActivityListView.swift`** — Goal definition screen. SwiftData `Activity` list with Add/Edit/Delete. "Continue" calls `FirestoreService.createTeam`.
- **`Onboarding/AppBlockingSelectionView.swift`** — App blocking setup (shown after team creation and after joining). Opens `FamilyActivityPicker`; selection saved to UserDefaults.
- **`Onboarding/TeamWelcomeView.swift`** — Post-creation welcome. Animated logo; invite code with copy button + optional "Share Invite" sheet; "Go to Pact" skips to ForgeView.
- **`Onboarding/OnboardingJoinShieldView.swift`** — 6-digit code entry screen to join an existing team.
- **`Onboarding/JoinShieldActivitiesView.swift`** — Shows the team's goal to a joining member before they confirm.

### Forge Pact

- **`Onboarding/ForgePactView.swift`** — Forge Pact agreement screen. Shows team name/goal, live "X of Y agreed" counter, "I Agree" CTA, and "Go to Pact" early-exit.
- **`Onboarding/PactFormedView.swift`** — Full-screen "The Pact is Formed" celebration. Shown when all members agree. Animated title and subtitle; Continue proceeds to Home.
- **`Onboarding/PactLaunchView.swift`** — Unused post-creation splash (superseded by `TeamWelcomeView`). Candidate for removal.

### Home Screen

- **`Home/HomeView.swift`** — Home tab. Header (avatar → `ProfileView` sheet), `ShieldProgressWheel` ring, infinite card carousel (health score + team progress), and today's goal card.
- **`Home/ShieldProgressWheel.swift`** — Circular progress ring component driven by `ShieldProgressViewModel`. Reflects today's approved / total activities ratio.
- **`Home/ShieldProgressViewModel.swift`** — `@MainActor ObservableObject` that computes ring progress and status text from `FirestoreService` data.

### Upload & Proof Submission

- **`Upload/UploadView.swift`** — Upload tab coordinator. Checks if user can submit; routes to `CameraScreen` or `SubmissionDetailView`. Houses `UploadProofView` full-screen flow.
- **`Upload/CameraScreen.swift`** — Live AVFoundation camera view (`CameraViewModel` + `AVCaptureSession`). No photo library access — live capture only. Flip/capture controls.
- **`Upload/ConfirmPhotoView.swift`** — Full-screen dark review screen. Previews captured photo; "Send Proof" submits via `FirestoreService.submitProof`.
- **`Upload/CameraPermissionExplainerView.swift`** — Intermediate sheet shown before the iOS camera permission dialog. Animated viewfinder, scan-line, green corner brackets.

### Team Feed & Voting

- **`Team/TeamView.swift`** — Team tab. `SwipeableCardStack` of pending submissions (approve/reject swipe + buttons); Highlights carousel of approved submissions; `ShieldMembersSection` with member progress bars and Share Invite link.

### Submission Detail

- **`Submission/SubmissionDetailView.swift`** — Sheet showing the current user's today's submission. Proof photo, status pill, approval count; "Replace Photo" for rejected submissions.
- **`Submission/SubmissionPeepView.swift`** — Swipe-down bottom sheet opened from TeamView pending/rejected cards. Full proof photo, per-member vote breakdown, "Nudge" for non-voters, "Replace Photo" for rejected.

### Profile

- **`Profile/ProfileView.swift`** — Profile sheet (opened from HomeView avatar). User identity, screen time bar chart (week/month/lifetime), activity stats, team card, and settings rows (Sign Out, Edit Team).
- **`Profile/EditTeamView.swift`** — Edit team activities sheet (admin only). CRUD via `FirestoreService` (`addGoal`, `updateGoal`, `deleteGoal`).

### Auth & Services

- **`Auth/AuthManager.swift`** — `@MainActor ObservableObject`. Owns Firebase Auth state. `signInWithGoogle()`, `signInWithApple()`, `signOut()` (provider-aware), `deleteAccountWithApple()`. Injected as `@EnvironmentObject` from `PactApp`.
- **`Services/FirestoreService.swift`** — `@MainActor ObservableObject`. All Firestore operations and real-time listeners: `saveUserProfile`, `createTeam` (CF-8), `joinTeam` (CF-7), `forgePact`, `submitProof`, `castVote`, `listenToTeam`, `listenToTodaysSubmissions`, `listenToMembers`, `updateFCMToken`, `addGoal`, `updateGoal`, `deleteGoal`. Injected as `@EnvironmentObject`.
- **`Services/AppBlockingService.swift`** — Manages `ManagedSettingsStore` and `FamilyControls` authorization. Applies/removes app restrictions based on Firestore `lockShieldActive` / `appUnlocked` signals.
- **`Services/DeepLinkManager.swift`** — Parses `pact://join/{inviteCode}` deep links and coordinates the join flow from `PactApp.onOpenURL`.

### Notifications

- **`Notifications/NotificationRouter.swift`** — `@MainActor ObservableObject`. Subscribes to `NotificationCenter.pactNotification`; drives `@Published var activeBanner` (foreground) and `@Published var pendingTabSwitch` (background tap). Defines `Notification.Name` extensions.
- **`Notifications/InAppNotificationBanner.swift`** — Snapchat-style top drop-down banner. Shows avatar, bold title, grey body. Spring slide-in; auto-dismisses after 4 s.

### Utilities & Models

- **`Utilities/ImageCache.swift`** — `NSCache`-backed async image cache for proof photo thumbnails (`CachedProofImage` view).
- **`Utilities/InputValidator.swift`** — Validation helpers (gamertag format, invite code format, etc.).
- **`Utilities/InputModifiers.swift`** — SwiftUI view modifiers for styled text fields and input formatting.
- **`Activity.swift`** — SwiftData `@Model` for locally-defined daily activities (used during team creation before Firestore write).
- **`ContentView.swift`** — Unused Xcode default placeholder. Can be removed.
- **`Item.swift`** — Unused Xcode default SwiftData `@Model`. Can be removed.

### App Extensions

- **`PactDeviceActivityMonitor/`** — `DeviceActivity` app extension. Schedules the daily morning lock cycle via `DeviceActivityMonitor`.
- **`PactShieldConfiguration/`** — `ShieldConfiguration` app extension. Customizes the blocking screen shown when a locked app is tapped (displays Pact branding and "Complete today's task to unlock").

## Product Vision

Pact is a social accountability app (see `Pact-PRD.md` for the full spec). Key concepts:

- **App locking:** Uses Apple Screen Time API (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) to lock distracting apps each morning until a daily goal is verified.
- **Proof submission:** Live camera only (no gallery uploads). Teammates vote to approve submissions; majority approval unlocks apps.
- **AI fallback:** Claude Vision API or GPT-4o used to auto-verify after ~2–3 hours of peer inactivity.
- **Shield progression:** Each team shares a visual "shield" that upgrades through 7 material tiers (Bronze → Platinum) based on streak consistency.
- **Backend:** Firebase — fully integrated. Firestore real-time listeners, Cloud Functions (CF-1 through CF-8 deployed), FCM push notifications, Firebase Storage for proof photos.

## Backend Architecture

**Stack: Firebase**
- **Firestore** — real-time data (teams, members, activities, votes)
- **Firebase Storage** — proof photo uploads
- **Firebase Auth** — anonymous auth at launch, upgradeable to named account
- **FCM (Firebase Cloud Messaging)** — push notifications for votes and approvals
- **Cloud Functions** — AI fallback verification pipeline (Claude Vision / GPT-4o)

Firebase was chosen over Supabase because:
1. FCM is required for vote/approval push notifications regardless of backend
2. Firestore real-time listeners are best-in-class for live vote counts on iOS
3. Firebase Storage + Cloud Functions simplify the AI verification pipeline
4. More mature iOS Swift SDK

### Firestore Data Model

See **[`datamodel-updated.md`](./datamodel-updated.md)** for the full schema — all collections, fields, Cloud Function descriptions, composite indexes, Storage lifecycle, and security rule strategy.

Collections overview:
```
users/{uid}
users/{uid}/teamMemberships/{teamId}
invites/{inviteCode}
teams/{teamId}
teams/{teamId}/members/{uid}
teams/{teamId}/goals/{goalId}
teams/{teamId}/goals/{goalId}/forgePactAgreements/{uid}
teams/{teamId}/dailyInstances/{date}
teams/{teamId}/dailyInstances/{date}/submissions/{uid}_{activityId}
teams/{teamId}/dailyInstances/{date}/submissions/{id}/votes/{voterId}
```

### Deep Linking
- Custom URL scheme: `pact://join/{inviteCode}`
- Handled in `PactApp.swift` via `.onOpenURL` — looks up team by `inviteCode`

## Project Conventions

- **Always use regular git branches** for feature work, not worktrees.
- **Branch naming for new features:** when starting a new feature, assume you should create a new branch with the pattern `<github-username>/<feature-name>`, e.g. `owusuys/carousel`, via `git checkout -b owusuys/feature-name`.
- **New screens:** When you add a new screen or full-screen sheet, add an entry to `pages.md` with the file path and a short description of what that file does.
- **Firebase CLI:** The `firebase` binary is not on PATH. Always prefix Firebase CLI commands with `npx`, e.g. `npx firebase deploy --only functions`.

## How Claude Should Work on New Features

For any task that involves planning or building a new feature or flow, **ask a few clarifying questions before writing code**. Focus on:

- **Goal**: what user outcome or story we’re aiming for.
- **Scope**: what’s in/out for this iteration and what to optimize for (e.g. speed vs polish).
- **UX**: key entry points, empty/error states, and how it should fit Pact’s existing UI.
- **Constraints**: relevant data model, Screen Time/API, performance, or policy limits.

If the request is ambiguous, ask 3–5 of the most important questions and make any assumptions explicit.

When working in **Plan mode**, always start by asking these clarifying questions (and any other critical design questions) before proposing an architecture, flow, or UI design, so the resulting plan is as high‑quality and aligned with the product vision as possible.

## UI Design Language

The app uses a **light theme** — clean, minimal, and high-contrast.

- **Light mode only** — white primary backgrounds throughout
- Clean sans-serif typography (SF Pro / system font)
- Black for headings, primary actions, and CTA buttons
- Grey for secondary text, labels, and contextual info
- Light grey (`#F4F4F7` range) for card and input field surfaces

### Color Palette

- **Main colors**
  - `#FFFFFF` — white (primary background of all screens)
  - `#000000` — black (main text, headings, and primary buttons with white label)
  - `#F9F8FD` — light grey (card backgrounds, input fields, icon containers)
  - Mid grey (`Color(white: 0.55)` range) — secondary text, placeholders, labels
  - The app should feel **minimalist**: white backgrounds, black for emphasis, grey for everything secondary.

### Key UI Rules
- **Backgrounds:** `Color.white` for all screens and sheets
- **Cards / rows:** Light grey fill (`Color(white: 0.96)` or `#F4F4F6`) so they lift off the white background
- **Primary CTA buttons:** Black fill (`Color.black`) with white label text
- **Icon containers:** Light grey rounded rectangle (`Color(white: 0.90)`)
- **Input fields:** Light grey fill (`Color(white: 0.94)`), black text, black tint cursor
- **Selected states:** Black fill, white icon/text (e.g. icon picker selection)
