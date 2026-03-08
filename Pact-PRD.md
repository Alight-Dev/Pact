# 🛡️ Pact
### *Earn Your Screen Time. Forge Your Shield.*

---

## Overview

Pact is a social accountability app that locks distracting apps each morning until users complete agreed-upon real-world goals within their team. Teams define a shared daily goal, each member submits live photo proof, and teammates vote to approve it. Once approved, their restricted apps unlock for the day.

Progress is tracked through a **shared team shield** — a physical, gem-forged artifact that upgrades through tiers based on team consistency. Miss days and the shield degrades. Stay consistent and it ascends from Bronze to Platinum.

> Real-world progress unlocks digital rewards. Your team forges — or fractures — together.

---

## Design Language

The visual identity is built around **gem-forged shield fragments** — faceted, glossy, metallic shards that fit together to form a hexagonal team shield. Each fragment represents a team member. The shield's material tier reflects the team's streak.

**Shield Tiers**

| Tier | Material | Color |
|------|----------|-------|
| 1 | Bronze | Warm copper-orange |
| 2 | Iron | Cool grey |
| 3 | Gold | Bright yellow with light burst |
| 4 | Shadow | Dark slate |
| 5 | Crystal | Soft blue-white glow |
| 6 | Emerald | Deep green |
| 7 | Platinum | Full composite, all shards lit |

The shield is always displayed on a **black background**. Shards glow and pulse when active. Fractured or dimmed shards indicate inactive or failing members.

**UI Aesthetic:** Light mode only. Clean, minimal, high-contrast. White primary backgrounds, black for headings and CTAs, light grey for cards and input fields. The shield itself is displayed against a dark/black surface when featured, but all app screens use a white background. Typography: clean sans-serif (SF Pro), black and grey.

---

## Core Features

### 1. Team Creation
- User creates a team and generates a shareable invite link
- Share via iMessage, WhatsApp, etc.
- 3–5 members per team (MVP)
- Roles: Admin + Members
- Each member is assigned a shield fragment shard

### 2. Goal Agreement System
- Admin defines: activity type, frequency, daily deadline
- Admin selects apps to restrict for the team
- All members must tap **Forge Pact** before the goal activates
- One active goal per team in V1

### 3. Morning App Lock
- Selected apps lock each morning via Apple Screen Time API (`FamilyControls`, `ManagedSettings`)
- Locked app shows custom Pact shield screen: *"Complete today's task to unlock."*
- Lock persists until individual submission is approved

### 4. Task Completion & Proof Submission
1. User taps **Complete Today's Task**
2. Live camera opens — no gallery uploads
3. Photo taken and submitted to team feed
4. Teammates approve with ✅ (majority required, no self-approval)

**Approval fallback tiers:**
- **Tier 1:** Peer majority approval (primary)
- **Tier 2:** AI vision verification after 2–3 hour inactivity
- **Tier 3:** Auto-approve after 6 hours with team-visible note

### 5. Individual App Unlock
- Approval unlocks **your own** restricted apps only
- Independent of teammates' completion status
- Immediate unlock on approval

### 6. Shield Progression System
Each team has one shared shield composed of individual member shards.

- ✅ Full team completion = shield maintains tier + streak increments
- ❌ Any member misses = their shard dims/cracks
- 🔥 Streak milestones = shield upgrades to next material tier
- 💀 Extended missed days = shard fractures, shield degrades a tier

**Streak milestones (MVP):**

| Streak | Shield Tier |
|--------|-------------|
| 0–6 days | Bronze |
| 7–13 days | Iron |
| 14–20 days | Gold |
| 21–29 days | Shadow |
| 30–44 days | Crystal |
| 45–59 days | Emerald |
| 60+ days | Platinum |

### 7. Team Feed
- Real-time feed of all proof submissions
- Shows: submitted, pending approval, approved, rejected
- Passive accountability — seeing teammates submit is motivating

### 8. Home Screen Widget
- Shield fragment + current tier
- Streak counter
- Daily completion status (e.g. 3/4 forged)
- Lock / unlocked status

---

## MVP Scope (V1)

- iOS only, Swift + SwiftUI
- 3–5 members per team
- 1 active goal per team
- Majority peer approval + AI fallback + auto-approve
- Shield progression (Bronze → Platinum)
- Home screen widget
- App locking via Screen Time API

---

## Tech Stack

- **Frontend:** Swift, SwiftUI
- **App Blocking:** FamilyControls, ManagedSettings, DeviceActivity
- **Backend:** Firebase (Firestore, Firebase Storage, Cloud Functions, FCM)
- **AI Verification:** Claude Vision API or GPT-4o vision endpoint (Phase 2 — auto-verify after peer inactivity)
- **Notifications:** Firebase Cloud Messaging (FCM) for approval requests, vote nudges, and streak alerts

---

## Monetization (Future)

**Free:** 1 team, 1 goal, limited app blocking, Bronze–Gold tiers only

**Pro:** Unlimited teams, multiple goals, full tier progression, AI verification, custom shard themes, analytics

---

## Core Value Proposition

Pact combines screen-time restriction, social verification, and visual prestige into one daily ritual. Your shield is a trophy your group earns together — and a reminder of what you stand to lose.

*No more solo discipline. Your team forges — or fractures — together.*
