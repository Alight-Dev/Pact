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
| `Pact/Onboarding/OnboardingFlowView.swift` | Coordinates the 5-step onboarding flow. Owns step state and slide transitions between steps. |
| `Pact/Onboarding/OnboardingGenderView.swift` | Step 0 of 5. Gender selection (e.g. selectable pills). |
| `Pact/Onboarding/OnboardingAgeView.swift` | Step 1 of 5. Age selection. |
| `Pact/Onboarding/OnboardingScreenTimeView.swift` | Step 2 of 5. Daily screen time estimate. |
| `Pact/Onboarding/OnboardingSignupView.swift` | Step 3 of 5. Sign-in wireframe: “Continue with Apple” / “Continue with Google”; logo animates to upper-middle. |
| `Pact/Onboarding/OnboardingProfileSetupView.swift` | Step 4 of 5. Nickname (suggested gamertag + manual) and avatar (emoji grid). |

---

## Main app

| File | Purpose |
|------|--------|
| `Pact/HomeScreenView.swift` | Main app screen. List of SwiftData activities; “Add Activity” opens `AddActivitySheet`. |
| `Pact/HomeScreenView.swift` → `AddActivitySheet` | Full-screen sheet to create an activity: name, description, icon picker. |

---

## Placeholders (candidates for removal)

| File | Purpose |
|------|--------|
| `Pact/ContentView.swift` | Unused Xcode default template (list of `Item`). Can be removed. |

---

*Add new screens/sheets here when you create them.*
