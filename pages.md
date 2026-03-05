# Pact — Screen & page reference

One place to see what each screen/sheet does. **When you add a new screen or full-screen sheet, add an entry here** (file path, one-line purpose, and optional notes).

---

## Entry / splash

| File | Purpose |
|------|--------|
| `Pact/SplashView.swift` | First screen after launch. Animated logo and “Get Started”; calls `onFinished` to transition into onboarding. |

---

## Onboarding (flow)

| File | Purpose |
|------|--------|
| `Pact/Onboarding/OnboardingFlowView.swift` | Coordinates the full 8-step onboarding flow (`OnboardingStep` enum, `totalSteps = 8`). Owns step state and slide transitions. When adding a new step: add a case to the enum, wire `onContinue`/`onBack` closures, set `currentStep` to the next integer, and bump `totalSteps` to 9 in every screen. |
| `Pact/Onboarding/OnboardingGenderView.swift` | Step 1 of 8 (`currentStep = 0`). Gender selection (selectable pills). |
| `Pact/Onboarding/OnboardingAgeView.swift` | Step 2 of 8 (`currentStep = 1`). Age range selection. |
| `Pact/Onboarding/OnboardingScreenTimeView.swift` | Step 3 of 8 (`currentStep = 2`). Daily screen time estimate. |
| `Pact/Onboarding/OnboardingProjectionInputsView.swift` | Step 4 of 8 (`currentStep = 3`). Slider for years with smartphone and app category selection. |
| `Pact/Onboarding/OnboardingLoadingView.swift` | Transient loading screen between ProjectionInputs and ProjectionView. 5 pulsing dots + "Loading..." text; auto-advances after ~2.2s. Not counted as a numbered step — no progress bar. |
| `Pact/Onboarding/OnboardingProjectionView.swift` | Step 5 of 8 (`currentStep = 4`). Animated display of projected lifetime screen time and reclaim stats. Continue button is disabled until the counting animation finishes (~0.8s). |
| `Pact/Onboarding/OnboardingRequestNotificationsView.swift` | Step 6 of 8 (`currentStep = 5`). Notification permission screen — social notification preview, requests iOS push notification permission via `UNUserNotificationCenter`. |
| `Pact/Onboarding/OnboardingSignupView.swift` | Step 7 of 8 (`currentStep = 6`). Sign-in screen: “Continue with Apple” / “Continue with Google”; logo animates to upper-middle. |
| `Pact/Onboarding/OnboardingProfileSetupView.swift` | Step 8 of 8 (`currentStep = 7`). Nickname (suggested gamertag + manual) and avatar picker (4×3 grid + full sheet). |
| `Pact/Onboarding/OnboardingCreateOrJoinShieldView.swift` | Post-onboarding: “Create a Shield” or “Join a Shield” selection screen. |
| `Pact/Onboarding/OnboardingComponents.swift` | Shared onboarding UI components: `SelectablePillButton` and `OnboardingProgressBar`. |

---

## Auth & Services

| File | Purpose |
|------|--------|
| `Pact/Auth/AuthManager.swift` | `@MainActor ObservableObject` that owns Firebase Auth state. Exposes `currentUser`, `signInWithGoogle()` (async/throws), and `signOut()`. Injected as an `@EnvironmentObject` from `PactApp`. |
| `Pact/Services/FirestoreService.swift` | `@MainActor ObservableObject` service layer for all Firestore operations. Methods: `saveUserProfile`, `createTeam` (calls CF-8), `joinTeam` (calls CF-7), `forgePact`, `listenToTeam`, `listenToTodaysSubmissions`, `castVote`, `updateFCMToken`. Injected as `@EnvironmentObject` from `PactApp`. |

---

## Notifications

| File | Purpose |
|------|--------|
| `Pact/AppDelegate.swift` | `UIApplicationDelegate` + `UNUserNotificationCenterDelegate` + `MessagingDelegate`. Intercepts foreground and background notification taps; posts to `NotificationCenter` via `.pactNotification`. Handles FCM token refresh via `.fcmTokenRefreshed`. Wired into SwiftUI via `@UIApplicationDelegateAdaptor`. |
| `Pact/Notifications/NotificationRouter.swift` | `@MainActor ObservableObject` that subscribes to `.pactNotification` and drives `@Published var activeBanner` (foreground) and `@Published var pendingTabSwitch` (background tap). Also defines `Notification.Name` extensions `.pactNotification` and `.fcmTokenRefreshed`. |
| `Pact/Notifications/InAppNotificationBanner.swift` | Snapchat-style top drop-down banner. Shows avatar (resolved from `firestoreService.members`), bold title, and grey body. Spring slide-in from top; auto-dismisses after 4 s; tap calls `onTap()` to switch tab. |

---

## Main app

| File | Purpose |
|------|--------|
| `Pact/HomeScreenView.swift` | Root tab container. Owns `selectedTab` state and renders `HomeView`, `UploadView`, or `TeamView`. Contains `FloatingTabBar` — a liquid-glass pill with Home, Upload (+), and Team tabs. |
| `Pact/Home/HomeView.swift` | Home tab. Header shows user avatar button that opens `ProfileView` as a sheet. Displays a progress ring, infinite card carousel (health score + team progress), and today's goal card. |
| `Pact/Profile/ProfileView.swift` | Profile sheet (opens from HomeView avatar tap). Shows user identity (avatar, name, gamertag, tier/streak pills), a screen time card with week/month/lifetime bar chart, activity stats (streak, completion, days saved), team card with stacked avatars, and settings rows (Edit Profile, Notifications, Edit Team (admin only), Sign Out). |
| `Pact/Profile/EditTeamView.swift` | Edit team activities sheet (admin only). Reads from `firestoreService.teamActivities`; supports add/edit/delete via Firestore CRUD (`addGoal`, `updateGoal`, `deleteGoal`). |
| `Pact/Upload/UploadView.swift` | Upload tab (center “+” button). Currently an empty stub with an “Upload” label. |
| `Pact/Upload/CameraPermissionExplainerView.swift` | Intermediate sheet shown before the iOS camera permission dialog. Explains live-capture requirement with animated viewfinder, scan-line, green corner brackets, and staggered feature rows. Green accent. |
| `Pact/Team/TeamView.swift` | Team tab. Currently an empty stub with a “Team” label. |
| `Pact/ActivityListView.swift` | Activities setup screen shown after onboarding when a user chooses “Create a Shield”. Users define daily activities here, then tap Continue which calls the `onContinue(inviteCode)` closure to transition to `TeamWelcomeView`. |
| `Pact/Onboarding/TeamWelcomeView.swift` | Post-team-creation welcome screen. Animated logo entrance (rises to upper area), then content fades in: “Welcome to Pact.” heading, invite code card with copy button, “Share Invite” (optional share sheet) and “Go to Pact” (proceeds to HomeScreen). Replaces the old forced share sheet + PactLaunchView combo. |
| `Pact/Onboarding/PactLaunchView.swift` | Post-activities splash/loading screen with maroon accents (currently unused — superseded by TeamWelcomeView). |
| `Pact/Onboarding/AppBlockingSelectionView.swift` | App blocking setup screen shown after team creation (before TeamWelcomeView) and after activity selection when joining (before HomeScreen). Users open FamilyActivityPicker to choose which apps get locked each morning; selection saved to UserDefaults. Skippable. |

---

## Placeholders (candidates for removal)

| File | Purpose |
|------|--------|
| `Pact/ContentView.swift` | Unused Xcode default template (list of `Item`). Can be removed. |

---

*Add new screens/sheets here when you create them.*
