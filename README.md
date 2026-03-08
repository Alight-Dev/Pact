# Pact

A social accountability app that locks distracting apps each morning until you and your team complete agreed-upon real-world goals together.

## Overview

Pact lets teams define a shared daily goal, submit live photo proof of completion, and vote to approve each other's submissions. Once approved, your restricted apps unlock for the day. Progress is tracked through a shared team shield that upgrades through material tiers (Bronze → Platinum) based on team consistency.

See [`Pact-PRD.md`](./Pact-PRD.md) for the full product spec and [`datamodel-updated.md`](./datamodel-updated.md) for the Firebase data model.

## Tech Stack

- **Language:** Swift 5.0 / SwiftUI
- **Persistence:** SwiftData
- **App Blocking:** FamilyControls, ManagedSettings, DeviceActivity (Screen Time API)
- **Backend:** Firebase — Firestore, Firebase Storage, Cloud Functions (TypeScript), FCM
- **AI Verification:** Claude Vision API / GPT-4o (Phase 2 — auto-verify after peer inactivity)
- **Notifications:** Firebase Cloud Messaging (FCM)

## Prerequisites

- macOS (latest)
- Xcode (latest stable, targeting iOS 26.2+)
- Node.js + npm (for Cloud Functions development)
- Firebase CLI: `npm install -g firebase-tools`

## Setup

### 1. Clone and open

```bash
git clone https://github.com/<org>/Pact.git
cd Pact
open Pact.xcodeproj
```

### 2. Firebase configuration

Add `GoogleService-Info.plist` (downloaded from Firebase Console) into `Pact/` — it is gitignored.

### 3. Device signing

Copy the example config and fill in your team ID:

```bash
cp Config/Development.xcconfig.example Config/Development.xcconfig
```

Edit `Config/Development.xcconfig` and set:
- `DEVELOPMENT_TEAM` — your Apple Developer team ID
- `BUNDLE_ID_PREFIX` — your reverse-domain prefix (e.g. `com.yourname`)

### 4. Run on device

```bash
xcodebuild -scheme Pact -destination 'platform=iOS,name=Your iPhone' build
```

> App locking features (`FamilyControls`, `ManagedSettings`) require a physical device with the Family Controls entitlement — they cannot be tested in the simulator.

### 5. Cloud Functions (optional)

```bash
cd functions
npm install
npx firebase deploy --only functions
```

## Project Structure

```
Pact/
├── Pact/                          # iOS app source
│   ├── PactApp.swift              # App entry point, routing, session restore
│   ├── AppDelegate.swift          # FCM, push notification handling
│   ├── SplashView.swift
│   ├── HomeScreenView.swift       # Root tab container + FloatingTabBar
│   ├── ActivityListView.swift     # Goal definition (create team flow)
│   ├── Onboarding/                # Full 8-step onboarding + join/forge flows
│   ├── Home/                      # HomeView, ShieldProgressWheel
│   ├── Team/                      # TeamView, voting card stack
│   ├── Upload/                    # Camera capture, proof submission
│   ├── Submission/                # SubmissionDetailView, SubmissionPeepView
│   ├── Profile/                   # ProfileView, EditTeamView
│   ├── Auth/                      # AuthManager (Firebase Auth)
│   ├── Services/                  # FirestoreService, AppBlockingService, DeepLinkManager
│   ├── Notifications/             # NotificationRouter, InAppNotificationBanner
│   └── Utilities/                 # ImageCache, InputValidator
│
├── PactDeviceActivityMonitor/     # DeviceActivity app extension (morning lock scheduling)
├── PactShieldConfiguration/       # ShieldConfiguration extension (custom block screen)
│
├── functions/                     # Firebase Cloud Functions (TypeScript)
│   └── src/                       # CF-1 through CF-8 (vote, submission, forge, streak, join, create)
│
├── Pact-PRD.md                    # Product requirements
├── CLAUDE.md                      # Claude Code guidance
├── TODO.md                        # MVP feature checklist
├── datamodel-updated.md           # Firestore schema reference
├── pages.md                       # Screen-by-screen reference
├── firestore.rules                # Firestore security rules
├── storage.rules                  # Firebase Storage rules
└── firestore.indexes.json         # Composite index definitions
```

## Documentation

| File | Purpose |
|------|---------|
| [`Pact-PRD.md`](./Pact-PRD.md) | Full product spec — vision, features, shield progression |
| [`CLAUDE.md`](./CLAUDE.md) | Architecture reference, conventions, build commands |
| [`TODO.md`](./TODO.md) | MVP feature checklist with completion status |
| [`datamodel-updated.md`](./datamodel-updated.md) | Firestore collections, Cloud Functions, security rules |
| [`pages.md`](./pages.md) | Every screen/sheet with file path and purpose |
