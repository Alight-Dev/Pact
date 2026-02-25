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

- **`PactApp.swift`** — App entry point. Uses `@AppStorage("hasCompletedOnboarding")` to gate between `WelcomeView` (first launch) and `ContentView` (main app). Initializes the SwiftData `ModelContainer`. On every launch, displays `SplashVideoView` as an overlay that fades out when the video finishes.
- **`SplashVideoView.swift`** — Plays `startup_animation.mp4` fullscreen on app launch using `AVPlayer` via `UIViewRepresentable`. Calls `onFinished` when playback completes, triggering a fade-out transition. Gracefully handles missing video file.
- **`WelcomeView.swift`** — Onboarding splash screen. Calls `onGetStarted` closure to set `hasCompletedOnboarding = true` and transition to the main app.
- **`ContentView.swift`** — Placeholder main view (Xcode default list/detail). Will be replaced with the real app UI.
- **`Item.swift`** — Placeholder SwiftData `@Model`. Replace with real domain models as features are built.

## Product Vision

Pact is a social accountability app (see `Pact-PRD.md` for the full spec). Key concepts:

- **App locking:** Uses Apple Screen Time API (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) to lock distracting apps each morning until a daily goal is verified.
- **Proof submission:** Live camera only (no gallery uploads). Teammates vote to approve submissions; majority approval unlocks apps.
- **AI fallback:** Claude Vision API or GPT-4o used to auto-verify after ~2–3 hours of peer inactivity.
- **Shield progression:** Each team shares a visual "shield" that upgrades through 7 material tiers (Bronze → Platinum) based on streak consistency.
- **Backend:** Firebase or Supabase (not yet integrated).

## Project Conventions

- **Always use regular git branches** (`git checkout -b feature/...`) for feature work, not worktrees.

## UI Design Language

Per the PRD, the target aesthetic is:
- **Dark mode only** — black to deep charcoal backgrounds
- Gem-forged shield fragments as the primary visual motif
- Gemstone textures on interactive elements, subtle inner glow on active states
- Clean sans-serif typography, white and light grey text
