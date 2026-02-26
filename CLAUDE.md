# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Keeping This File Updated

This file should evolve with the project. Whenever a meaningful feature is added, an architectural decision is made, a new dependency is integrated, or the product vision shifts, update the relevant section here. The goal is for this file to always reflect the current state of the codebase accurately — not a snapshot from early development.

## Build & Run

Open in Xcode and run with ⌘R, or from the terminal:

```bash
open Pact.xcodeproj
```

To build from the command line:

```bash
xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16' build
```

To run tests:

```bash
xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16' test
```

To run a single test class:

```bash
xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PactTests/PactTests test
```

> Features using `FamilyControls` and `ManagedSettings` (app blocking) require a **physical device** with a provisioning profile that includes the Family Controls entitlement. They cannot be tested in the simulator.

## Project Details

- **Language:** Swift 5.0
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **iOS Deployment Target:** 26.2
- **Bundle ID:** `cmc.Pact`

## Architecture

The app is in early development. Current structure:

- **`PactApp.swift`** — App entry point. Uses `@AppStorage("hasCompletedOnboarding")` to gate between `SplashView` (first launch) and `HomeScreenView` (main app). Initializes the SwiftData `ModelContainer` with `Item` and `Activity` models.
- **`SplashView.swift`** — Animated splash screen with logo animation (~1.6s) followed by a "Get Started" button. Calls `onFinished` to set `hasCompletedOnboarding = true` and transition to `HomeScreenView`.
- **`WelcomeView.swift`** — Alternate onboarding view (currently unused). Calls `onGetStarted` closure.
- **`HomeScreenView.swift`** — Main app screen. Displays a list of `Activity` items on a white background with light grey cards. Includes a black "Add Activity" button that opens `AddActivitySheet` (a full-screen light-themed sheet with name, description, and icon picker). `ActivityRowView` renders each activity card.
- **`Activity.swift`** — SwiftData `@Model` for user-created daily activities. Fields: `name`, `activityDescription`, `iconName` (SF Symbol), `order`, `createdAt`.
- **`ContentView.swift`** — Unused placeholder (Xcode default). Can be removed.
- **`Item.swift`** — Unused placeholder SwiftData `@Model`. Can be removed.

## Product Vision

Pact is a social accountability app (see `Pact-PRD.md` for the full spec). Key concepts:

- **App locking:** Uses Apple Screen Time API (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) to lock distracting apps each morning until a daily goal is verified.
- **Proof submission:** Live camera only (no gallery uploads). Teammates vote to approve submissions; majority approval unlocks apps.
- **AI fallback:** Claude Vision API or GPT-4o used to auto-verify after ~2–3 hours of peer inactivity.
- **Shield progression:** Each team shares a visual "shield" that upgrades through 7 material tiers (Bronze → Platinum) based on streak consistency.
- **Backend:** Firebase or Supabase (not yet integrated).

## Project Conventions

- **Always use regular git branches** for feature work, not worktrees.
- **Branch naming for new features:** when starting a new feature, assume you should create a new branch with the pattern `<github-username>/<feature-name>`, e.g. `owusuys/carousel`, via `git checkout -b owusuys/feature-name`.

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
