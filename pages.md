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
| `Pact/Onboarding/OnboardingProjectionView.swift` | Step 5 of 8 (`currentStep = 4`). Animated display of projected lifetime screen time and reclaim stats. |
| `Pact/Onboarding/OnboardingRequestNotificationsView.swift` | Step 6 of 8 (`currentStep = 5`). Notification permission screen — social notification preview, requests iOS push notification permission via `UNUserNotificationCenter`. |
| `Pact/Onboarding/OnboardingSignupView.swift` | Step 7 of 8 (`currentStep = 6`). Sign-in screen: “Continue with Apple” / “Continue with Google”; logo animates to upper-middle. |
| `Pact/Onboarding/OnboardingProfileSetupView.swift` | Step 8 of 8 (`currentStep = 7`). Nickname (suggested gamertag + manual) and avatar picker (4×3 grid + full sheet). |
| `Pact/Onboarding/OnboardingCreateOrJoinShieldView.swift` | Post-onboarding: “Create a Shield” or “Join a Shield” selection screen. |
| `Pact/Onboarding/OnboardingComponents.swift` | Shared onboarding UI components: `SelectablePillButton` and `OnboardingProgressBar`. |

---

## Main app

| File | Purpose |
|------|--------|
| `Pact/ActivityListView.swift` | Main app screen. List of SwiftData activities; “Add Activity” opens `AddActivitySheet`. |
| `Pact/ActivityListView.swift` → `AddActivitySheet` | Full-screen sheet to create an activity: name, description, icon picker. |

---

## Placeholders (candidates for removal)

| File | Purpose |
|------|--------|
| `Pact/ContentView.swift` | Unused Xcode default template (list of `Item`). Can be removed. |

---

*Add new screens/sheets here when you create them.*
