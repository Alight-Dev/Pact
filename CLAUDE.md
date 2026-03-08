# CLAUDE.md

Guidance for Claude when working in this repository. Update this file when features, architecture, or product direction change so it stays accurate.

## Documentation map

| Topic | Document |
|-------|----------|
| MVP features & completion | **[`TODO.md`](./TODO.md)** |
| Screens, sheets, file paths | **[`pages.md`](./pages.md)** |
| Product spec & vision | **[`Pact-PRD.md`](./Pact-PRD.md)** |
| Firebase schema, Cloud Functions, indexes | **[`datamodel-updated.md`](./datamodel-updated.md)** |
| Setup, build, run, tooling | **[`README.md`](./README.md)** |

## TODO.md rules

1. **Before work:** Scan relevant Swift/TypeScript to see if any TODO items are already done; check them off.
2. **After implementing:** Mark the corresponding `[ ]` as `[x]` in `TODO.md` before moving on.
3. **New work:** Add new requirements to the right section in `TODO.md`.
4. **Housekeeping:** Periodically move completed items to the "Completed Items Archive" in `TODO.md`.

### Rules for Claude when working on this project:

1. **Incremental scan before starting work:** At the beginning of every coding session (or whenever asked), scan the relevant Swift source files and Cloud Function TypeScript files to check whether any `TODO.md` items have been completed since the last update. Check off any completed items you discover.
2. **Check off on completion:** Immediately after implementing a feature or wiring a piece of functionality, open `TODO.md` and change the corresponding `[ ]` to `[x]`. Do this before moving on to the next task.
3. **Add new items:** If you discover a new requirement or sub-task not currently listed, add it to the appropriate section in `TODO.md` before starting work on it.
4. **Move completed items:** Periodically move large groups of completed (`[x]`) items to the "Completed Items Archive" section at the bottom of `TODO.md` to keep the active list readable.

App blocking (FamilyControls / ManagedSettings) requires a **physical device** with the Family Controls entitlement; not testable in the simulator.

## Project

Swift 5, SwiftUI, SwiftData. iOS 26.2. Bundle ID via `BUNDLE_ID_PREFIX` in `Config/Development.xcconfig`.

## Architecture

See **[`pages.md`](./pages.md)** for the full per-screen reference (file path + purpose for every screen and sheet). Below is the structural overview.

- **Environment:** `AuthManager`, `FirestoreService`, `NotificationRouter` from `PactApp` as `@EnvironmentObject`.
- **Data:** Firestore listeners in `FirestoreService` (`listenToTeam`, `listenToTodaysSubmissions`, `listenToMembers`); views bind to `@Published`.
- **App blocking:** `AppBlockingService` + `ManagedSettingsStore`; responds to Firestore `lockShieldActive` / `appUnlocked`; `PactDeviceActivityMonitor` for schedule, `PactShieldConfiguration` for block UI.
- **Camera:** AVFoundation only (`CameraScreen` → `ConfirmPhotoView`); no photo library.
- **Deep links:** `pact://join/{inviteCode}` via `DeepLinkManager` and `PactApp.onOpenURL`.

## Product & backend

- **Vision:** **[`Pact-PRD.md`](./Pact-PRD.md)** — lock apps by morning, live photo proof, peer vote to unlock, shared shield tiers (Bronze → Platinum).
- **Backend:** **[`datamodel-updated.md`](./datamodel-updated.md)** — collections, Cloud Functions CF-1–CF-8, indexes, Storage, security.

## Conventions

- Use normal git branches for features; name them `<github-username>/<feature-name>`.
- New screens/sheets: add an entry to **`pages.md`** (path + one-line purpose).
- Firebase CLI: use `npx`, e.g. `npx firebase deploy --only functions`.

## New features

Ask a few clarifying questions before coding: **goal**, **scope** (in/out, speed vs polish), **UX** (entry points, empty/error states), **constraints** (data model, Screen Time, policy). In Plan mode, do this before proposing architecture or UI.

## UI design

Light theme only: white backgrounds, black for headings and primary CTAs, grey for secondary. High contrast and minimal.

- **Backgrounds:** `Color.white` for screens/sheets.
- **Cards/rows:** Light grey (`Color(white: 0.96)` / `#F4F4F6`).
- **Primary CTA:** Black fill, white label.
- **Inputs:** Light grey fill (`Color(white: 0.94)`), black text.
- **Icon containers:** Light grey rounded rect (`Color(white: 0.90)`).
- **Selected:** Black fill, white icon/text.

Apply strong mobile UI/UX, accessibility, and typography; keep flows clear and consistent with this system.
