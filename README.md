# Pact

A social accountability app that locks distracting apps each morning until you and your team complete agreed-upon real-world goals together.

## Overview

Pact (internally codenamed GoBio) lets teams define a shared daily goal, submit live photo proof of completion, and vote to approve each other's submissions. Once approved, your restricted apps unlock for the day. Progress is tracked through a shared team shield that upgrades through material tiers based on team consistency.

See [`Pact-PRD.md`](./Pact-PRD.md) for the full product specification.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **App Blocking:** FamilyControls, ManagedSettings, DeviceActivity (Screen Time API)
- **Backend:** Firebase or Supabase (TBD)
- **AI Verification:** Claude Vision API or GPT-4o vision endpoint
- **Notifications:** APNs

## Prerequisites

- macOS (latest)
- Xcode (latest stable)

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/<org>/Pact.git
   cd Pact
   ```
2. Open the project in Xcode:
   ```bash
   open Pact.xcodeproj
   ```
3. Select a simulator or connected device and press **Run** (⌘R).

> Note: Features that use FamilyControls and ManagedSettings require a physical device with a provisioning profile that includes the Family Controls entitlement.

## Project Structure

```
Pact/
├── Pact.xcodeproj/   # Xcode project
├── Pact/             # App source
├── Pact-PRD.md       # Product requirements document
└── README.md
```
