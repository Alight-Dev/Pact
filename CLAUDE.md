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

See **[`pages.md`](./pages.md)** for the full per-screen reference (file path + purpose for every screen and sheet). Below is the structural overview.

### Directory map

```
Pact/
├── PactApp.swift              # Entry point — session restore, routing, env object injection
├── AppDelegate.swift          # FCM delegate, notification interception
├── SplashView.swift
├── HomeScreenView.swift       # Root tab container + FloatingTabBar
├── ActivityListView.swift     # Goal definition (create-team flow)
├── Activity.swift             # SwiftData @Model (local, pre-Firestore)
├── Onboarding/                # 8-step flow + name confirm + create/join/forge screens
├── Home/                      # HomeView, ShieldProgressWheel, ShieldProgressViewModel
├── Team/                      # TeamView (voting card stack, highlights, member list)
├── Upload/                    # UploadView coordinator, CameraScreen, ConfirmPhotoView
├── Submission/                # SubmissionDetailView, SubmissionPeepView
├── Profile/                   # ProfileView, EditTeamView
├── Auth/                      # AuthManager (Firebase Auth — Apple + Google)
├── Services/                  # FirestoreService, AppBlockingService, DeepLinkManager
├── Notifications/             # NotificationRouter, InAppNotificationBanner
└── Utilities/                 # ImageCache, InputValidator, InputModifiers
PactDeviceActivityMonitor/     # DeviceActivity extension — daily morning lock scheduling
PactShieldConfiguration/       # ShieldConfiguration extension — custom block screen
functions/src/                 # Cloud Functions CF-1 through CF-8 (TypeScript)
```

### Key architectural patterns

- **Environment injection:** `AuthManager`, `FirestoreService`, and `NotificationRouter` are instantiated in `PactApp` and injected as `@EnvironmentObject` — access them via `@EnvironmentObject var firestoreService: FirestoreService` in any view.
- **Real-time data:** All live team/submission/vote data flows through `FirestoreService` Firestore listeners (`listenToTeam`, `listenToTodaysSubmissions`, `listenToMembers`). Views observe `@Published` properties; no manual polling.
- **App blocking:** `AppBlockingService` wraps `ManagedSettingsStore`. It reacts to Firestore `lockShieldActive` / `appUnlocked` flags. The `PactDeviceActivityMonitor` extension handles the daily lock schedule; `PactShieldConfiguration` customises the block screen.
- **Camera:** Live capture only via AVFoundation (`CameraScreen` → `ConfirmPhotoView`). No photo library access.
- **Deep links:** `pact://join/{inviteCode}` — parsed by `DeepLinkManager`, coordinated from `PactApp.onOpenURL`.

## Product Vision

See **[`Pact-PRD.md`](./Pact-PRD.md)** for the full spec. In brief: apps lock each morning via the Screen Time API; members submit live photo proof; teammates vote to approve; majority approval unlocks apps. Teams share a shield that tiers up (Bronze → Platinum) based on streak consistency.

## Backend

**Stack:** Firebase — Firestore (real-time listeners), Firebase Storage (proof photos), Firebase Auth (Apple + Google), FCM (push notifications), Cloud Functions CF-1–CF-8 (vote processing, submission handling, streak/tier computation, team create/join).

**Schema:** See **[`datamodel-updated.md`](./datamodel-updated.md)** for all collections, fields, Cloud Function descriptions, composite indexes, Storage lifecycle, and security rule strategy.

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
