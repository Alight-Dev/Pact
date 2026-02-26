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
| `Pact/Onboarding/OnboardingFlowView.swift` | Coordinates the 8-step onboarding flow. Owns step state and slide transitions between steps. |
| `Pact/Onboarding/OnboardingGenderView.swift` | Step 0 of 7. Gender selection (selectable pills). |
| `Pact/Onboarding/OnboardingAgeView.swift` | Step 1 of 7. Age range selection. |
| `Pact/Onboarding/OnboardingScreenTimeView.swift` | Step 2 of 7. Daily screen time estimate. |
| `Pact/Onboarding/OnboardingProjectionInputsView.swift` | Step 3 of 7. Slider for years with smartphone and app category selection. |
| `Pact/Onboarding/OnboardingProjectionView.swift` | Step 4 of 7. Animated display of projected lifetime screen time and reclaim stats. |
| `Pact/Onboarding/OnboardingRequestNotificationsView.swift` | Step 5 of 7. Notification permission screen — social notification preview, requests iOS push notification permission. |
| `Pact/Onboarding/OnboardingSignupView.swift` | Step 6 of 7. Sign-in wireframe: “Continue with Apple” / “Continue with Google”; logo animates to upper-middle. |
| `Pact/Onboarding/OnboardingProfileSetupView.swift` | Step 7 of 7. Nickname (suggested gamertag + manual) and avatar (emoji grid). |
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
