# Pact — Screen & page reference

One place to see what each screen/sheet does. **When you add a new screen or full-screen sheet, add an entry here** (file path, one-line purpose, and optional notes).

---

## Entry / splash

| File | Purpose |
|------|--------|
| `Pact/SplashView.swift` | First screen after launch. Animated logo and "Get Started"; calls `onFinished` to transition into onboarding. |

---

## Onboarding (flow)

| File | Purpose |
|------|--------|
| `Pact/Onboarding/OnboardingFlowView.swift` | Coordinates the full 8-step onboarding flow (`OnboardingStep` enum, `totalSteps = 8`). Owns step state and slide transitions. When adding a new step: add a case to the enum, wire `onContinue`/`onBack` closures, set `currentStep` to the next integer, and bump `totalSteps`. |
| `Pact/Onboarding/OnboardingGenderView.swift` | Step 1 of 8 (`currentStep = 0`). Gender selection (selectable pills). |
| `Pact/Onboarding/OnboardingAgeView.swift` | Step 2 of 8 (`currentStep = 1`). Age range selection. |
| `Pact/Onboarding/OnboardingScreenTimeView.swift` | Step 3 of 8 (`currentStep = 2`). Daily screen time estimate. |
| `Pact/Onboarding/OnboardingProjectionInputsView.swift` | Step 4 of 8 (`currentStep = 3`). Slider for years with smartphone and app category selection. |
| `Pact/Onboarding/OnboardingLoadingView.swift` | Transient loading screen between ProjectionInputs and ProjectionView. 5 pulsing dots + "Loading..." text; auto-advances after ~2.2 s. Not counted as a numbered step — no progress bar. |
| `Pact/Onboarding/OnboardingProjectionView.swift` | Step 5 of 8 (`currentStep = 4`). Animated display of projected lifetime screen time and reclaim stats. Continue button is disabled until the counting animation finishes (~0.8 s). |
| `Pact/Onboarding/OnboardingRequestNotificationsView.swift` | Step 6 of 8 (`currentStep = 5`). Notification permission screen — social notification preview, requests iOS push notification permission via `UNUserNotificationCenter`. |
| `Pact/Onboarding/OnboardingSignupView.swift` | Step 7 of 8 (`currentStep = 6`). Sign-in screen: "Continue with Apple" / "Continue with Google"; logo animates to upper-middle. |
| `Pact/Onboarding/OnboardingNameConfirmationView.swift` | Shown right after sign-up (outside the 8-step flow). Pre-fills first/last name from Apple/Google Auth; user can edit and tap Continue to save to Firebase Auth, then routing proceeds (onboarding, join shield, or forge). Back signs out and returns to splash. |
| `Pact/Onboarding/OnboardingProfileSetupView.swift` | Step 8 of 8 (`currentStep = 7`). Nickname (suggested gamertag + manual) and avatar picker (4×3 grid + full sheet). |
| `Pact/Onboarding/OnboardingScreenTimeAccessIntroView.swift` | Explains Screen Time / FamilyControls before triggering `FamilyControls` authorization request. |
| `Pact/Onboarding/OnboardingScreenTimeApprovedView.swift` | Confirmation screen shown after Screen Time access is granted. |
| `Pact/Onboarding/OnboardingCreateOrJoinSheildView.swift` | Post-onboarding: "Create a Shield" or "Join a Shield" selection screen. *(Note: filename has a typo — "Sheild".)* |
| `Pact/Onboarding/OnboardingComponents.swift` | Shared onboarding UI components: `SelectablePillButton` and `OnboardingProgressBar`. |

---

## Team Creation

| File | Purpose |
|------|--------|
| `Pact/Onboarding/OnboardingTeamNameView.swift` | Team name entry screen. First step of the create-shield flow after `OnboardingCreateOrJoinSheildView`. |
| `Pact/ActivityListView.swift` | Goal definition screen. SwiftData `Activity` list with Add/Edit/Delete. "Continue" calls `FirestoreService.createTeam` (CF-8) and transitions to `AppBlockingSelectionView` then `TeamWelcomeView`. |
| `Pact/Onboarding/AppBlockingSelectionView.swift` | App blocking setup screen. Shown after team creation (admin) and after activity review when joining (member). Opens `FamilyActivityPicker`; selection saved to UserDefaults. Skippable. |
| `Pact/Onboarding/TeamWelcomeView.swift` | Post-team-creation welcome screen. Animated logo entrance, invite code card with copy button, optional "Share Invite" sheet, and "Go to Pact" CTA (proceeds to ForgePactView). |

---

## Join Team

| File | Purpose |
|------|--------|
| `Pact/Onboarding/OnboardingJoinShieldView.swift` | 6-digit numeric invite code entry screen. Calls `FirestoreService.joinTeam` (CF-7) on submit. |
| `Pact/Onboarding/JoinShieldActivitiesView.swift` | Shows the joining member the team's goal(s) before they confirm. Transitions to `AppBlockingSelectionView` then `HomeScreenView`. |

---

## Forge Pact

| File | Purpose |
|------|--------|
| `Pact/Onboarding/ForgePactView.swift` | Forge Pact agreement screen. Shows team name and goal, live "X of Y members agreed" counter, rounded "I Agree" CTA, and "Go to Pact" so users can proceed without waiting. When everyone agrees, presents `PactFormedView` then continues to Home. |
| `Pact/Onboarding/PactFormedView.swift` | Full-screen "The Pact is Formed" celebration. Shown when the goal becomes active (everyone agreed). Interrupts `ForgePactView` (then continues to Home) or `HomeScreenView` (any tab). Animated title and subtitle; Continue dismisses. |

---

## Auth & Services

| File | Purpose |
|------|--------|
| `Pact/Auth/AuthManager.swift` | `@MainActor ObservableObject` that owns Firebase Auth state. Exposes `currentUser`, `signInWithGoogle()`, `signInWithApple()`, `deleteAccountWithApple()`, and `signOut()` (provider-aware). Injected as `@EnvironmentObject` from `PactApp`. |
| `Pact/Services/FirestoreService.swift` | `@MainActor ObservableObject` service layer for all Firestore operations and real-time listeners. Key methods: `saveUserProfile`, `createTeam` (CF-8), `joinTeam` (CF-7), `forgePact`, `submitProof`, `castVote`, `listenToTeam`, `listenToTodaysSubmissions`, `listenToMembers`, `updateFCMToken`, `addGoal`, `updateGoal`, `deleteGoal`. Injected as `@EnvironmentObject`. |
| `Pact/Services/AppBlockingService.swift` | Manages `ManagedSettingsStore` and `FamilyControls` authorization. Applies/removes app restrictions based on Firestore `lockShieldActive` and `appUnlocked` signals. |
| `Pact/Services/DeepLinkManager.swift` | Parses `pact://join/{inviteCode}` deep links and coordinates the join flow from `PactApp.onOpenURL`. |

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
| `Pact/Home/HomeView.swift` | Home tab. Header shows user avatar button that opens `ProfileView` as a sheet. Displays a `ShieldProgressWheel`, infinite card carousel (health score + team progress), and today's goal card with per-activity completion rows. |
| `Pact/Home/ShieldProgressWheel.swift` | Circular progress ring component. Driven by `ShieldProgressViewModel`; reflects today's approved / total activities ratio. |
| `Pact/Home/ShieldProgressViewModel.swift` | `@MainActor ObservableObject` that computes ring progress and status text from `FirestoreService` approved submission data. |
| `Pact/Profile/ProfileView.swift` | Profile sheet (opens from HomeView avatar tap). Shows user identity (avatar, name, gamertag, tier/streak pills), a screen time card with week/month/lifetime bar chart, activity stats (streak, completion, days saved), team card with stacked avatars, and settings rows (Edit Profile, Notifications, Edit Team (admin only), Sign Out). |
| `Pact/Profile/EditTeamView.swift` | Edit team activities sheet (admin only). Reads from `firestoreService.teamActivities`; supports add/edit/delete via Firestore CRUD (`addGoal`, `updateGoal`, `deleteGoal`). |
| `Pact/Team/TeamView.swift` | Team tab. `SwipeableCardStack` of pending submissions (approve/reject via swipe or buttons); Highlights carousel for approved submissions; `ShieldMembersSection` with per-member progress bars and Share Invite link (admin). |
| `Pact/ActivityListView.swift` | (See Team Creation above.) |

---

## Upload & Proof Submission

| File | Purpose |
|------|--------|
| `Pact/Upload/UploadView.swift` | Upload tab coordinator. Checks `canSubmitToday` from `FirestoreService`; if no submission yet, presents `UploadProofView` (camera flow); if submission exists and is non-rejected, opens `SubmissionDetailView` instead. |
| `Pact/Upload/CameraScreen.swift` | Live AVFoundation camera view with `CameraViewModel` and `AVCaptureSession`. No photo library access — live capture only. Supports front/rear flip and captures a still. |
| `Pact/Upload/ConfirmPhotoView.swift` | Full-screen dark review screen shown after capture. Displays the captured image; "Send Proof" calls `FirestoreService.submitProof` (uploads to Storage, writes submission doc). |
| `Pact/Upload/CameraPermissionExplainerView.swift` | Intermediate sheet shown before the iOS camera permission dialog. Explains live-capture requirement with animated viewfinder, scan-line, green corner brackets, and staggered feature rows. |

---

## Submission Detail

| File | Purpose |
|------|--------|
| `Pact/Submission/SubmissionDetailView.swift` | Sheet showing the current user's today's submission. Displays proof photo (`CachedProofImage`), a colour-coded status pill (pending/approved/rejected), and approval count. Shows a "Replace Photo" button when status is `rejected`, which opens `UploadProofView` full-screen. Accessed by tapping the status row in `HomeView.todayGoalCard` or by tapping `+` in the tab bar when a non-rejected submission already exists. |
| `Pact/Submission/SubmissionPeepView.swift` | Swipe-down bottom sheet opened by tapping a pending or rejected card in the card stack on `TeamView`. Shows full-width proof photo, submission metadata (activity name, submitted time, status pill, approval count), per-member vote breakdown (approved / rejected / hasn't voted), and a "Nudge" button for teammates who haven't voted yet. Also includes a "Replace Photo" button for rejected submissions. |

---

## Placeholders (candidates for removal)

| File | Purpose |
|------|--------|
| `Pact/ContentView.swift` | Unused Xcode default template. Can be removed. |
| `Pact/Item.swift` | Unused Xcode default SwiftData `@Model`. Can be removed. |

---

*Add new screens/sheets here when you create them.*
