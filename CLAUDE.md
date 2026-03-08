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

Current structure:

- **`PactApp.swift`** — App entry point. Uses `@State` booleans (`showOnboarding`, `showShieldSelection`, `showHomeScreen`) to gate between `SplashView` → `OnboardingFlowView` → `OnboardingCreateOrJoinShieldView` → `HomeScreenView`. Initializes the SwiftData `ModelContainer` with `Item` and `Activity` models.
- **`SplashView.swift`** — Animated splash screen with logo spring animation. "Get Started" calls `onFinished` which transitions to `OnboardingFlowView`.
- **`Onboarding/OnboardingFlowView.swift`** — Step coordinator for the full onboarding sequence. Uses a private `OnboardingStep` enum (8 steps) and slide transitions between screens.
- **`Onboarding/OnboardingGenderView.swift`** — Step 0 of 7. Gender selection.
- **`Onboarding/OnboardingAgeView.swift`** — Step 1 of 7. Age selection.
- **`Onboarding/OnboardingScreenTimeView.swift`** — Step 2 of 7. Daily screen time estimate.
- **`Onboarding/OnboardingProjectionInputsView.swift`** — Step 3 of 7. Slider for years with smartphone and app category selection.
- **`Onboarding/OnboardingProjectionView.swift`** — Step 4 of 7. Animated display of projected lifetime screen time and days to reclaim. Uses `ScreenTimeProjectionEngine` for calculations.
- **`Onboarding/OnboardingRequestNotificationsView.swift`** — Step 5 of 7. Notification permission screen. Shows a social notification preview and requests iOS push notification permission via `UNUserNotificationCenter`.
- **`Onboarding/OnboardingSignupView.swift`** — Step 6 of 7. Apple / Google sign-in wireframe. Animated logo rises to upper-middle.
- **`Onboarding/OnboardingProfileSetupView.swift`** — Step 7 of 7. Nickname (Xbox-style gamertag generator + manual entry) and avatar selection (3×3 emoji grid).
- **`Onboarding/OnboardingCreateOrJoinShieldView.swift`** — Post-onboarding screen. "Create a Shield" or "Join a Shield" selection with animated logo entrance.
- **`Onboarding/OnboardingComponents.swift`** — Shared components: `SelectablePillButton`, `OnboardingProgressBar`.
- **`ActivityListView.swift`** — Main app screen. SwiftData `Activity` list with "Add Activity" sheet.
- **`Activity.swift`** — SwiftData `@Model` for user-created daily activities.
- **`ContentView.swift`** — Unused placeholder (Xcode default). Can be removed.
- **`Item.swift`** — Unused placeholder SwiftData `@Model`. Can be removed.

## Product Vision

Pact is a social accountability app (see `Pact-PRD.md` for the full spec). Key concepts:

- **App locking:** Uses Apple Screen Time API (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) to lock distracting apps each morning until a daily goal is verified.
- **Proof submission:** Live camera only (no gallery uploads). Teammates vote to approve submissions; majority approval unlocks apps.
- **AI fallback:** Claude Vision API or GPT-4o used to auto-verify after ~2–3 hours of peer inactivity.
- **Shield progression:** Each team shares a visual "shield" that upgrades through 7 material tiers (Bronze → Platinum) based on streak consistency.
- **Backend:** Firebase (chosen — see Backend Architecture section below). Not yet integrated.

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

```
/teams/{teamId}
  - name: String
  - creatorId: String
  - inviteCode: String        ← short unique code, e.g. "X7K2P"
  - createdAt: Timestamp

/teams/{teamId}/activities/{activityId}
  - name: String
  - description: String
  - iconName: String          ← SF Symbol name
  - repeatDays: [Int]         ← 0 = Sunday … 6 = Saturday
  - order: Int

/teams/{teamId}/members/{userId}
  - displayName: String
  - joinedAt: Timestamp
  - optedInActivityIds: [String]   ← IDs of activities they committed to
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
