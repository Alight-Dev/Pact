# How `activityName` Is Passed From UI to Firebase

Use this to verify at each step that the activity name is correct. If it breaks at a step, the bug is at or before that step.

---

## Step 1: Where the name originally comes from

**Source:** `UploadView.activityOptions`

- If the user has team goals from Firestore: names come from `firestoreService.userActivities` (each `TeamActivity.name` → `ActivityOption.name`). Empty names are replaced with `"Unnamed"`.
- If there are no goals: a **fallback list** is used (Morning Run, Study, Meditate, Gym, Reading, Practice) — **"swim" is not in this list.**

**Check:** On the **camera screen** (before you take the photo), does the **carousel** show "swim" as one of the activities you can select?

- If **NO** → The problem is Step 1: either `userActivities` is empty (so fallback is used and "swim" never appears), or the "swim" goal in Firestore has a wrong/empty `name`. Fix: ensure the "swim" goal exists and is loaded, and that you’re opted in if your app filters by opted-in activities.
- If **YES** → Go to Step 2.

---

## Step 2: Activity selected at capture time

**Source:** `CameraScreen` → when you tap the shutter, `CameraViewModel` uses `viewModel.selectedActivity` (the activity currently selected in the carousel) and calls `onCapture(image, activity)`.

**UploadView** receives that in:

```swift
onCapture: { image, activity in
    capturedImage = image
    selectedActivity = activity
}
```

So `UploadView.selectedActivity` is the activity you had selected when you took the photo (e.g. the one with `name: "swim"`).

**Check:** After you take the photo, on the **confirm screen**, does it say **"Submitting proof for"** and then **"swim"** (the same name you had selected in the carousel)?

- If **NO** → The problem is Step 2: the wrong activity is being passed from the camera (e.g. carousel selection not in sync with `viewModel.selectedActivity` at capture).
- If **YES** → Go to Step 3.

---

## Step 3: Confirm screen captures the name and calls the callback

**Source:** `ConfirmPhotoView` — when you tap **"Send Proof"**:

1. It does `let capturedName = String(selectedActivity.name)` (the same `selectedActivity` used for the "Submitting proof for **swim**" text).
2. It calls `onSubmit(capturedActivity, capturedName)`.

So the **second argument** to `onSubmit` is the activity name string (e.g. `"swim"`).

**Check:** Add a temporary print in `ConfirmPhotoView` right before the `Task` (e.g. `print("DEBUG ConfirmPhotoView capturedName: \(capturedName)")`). When you tap "Send Proof", does the console show `capturedName: swim`?

- If **NO** (empty, "Proof", or wrong) → The problem is Step 3: `selectedActivity.name` on the confirm screen is wrong or empty.
- If **YES** → Go to Step 4.

---

## Step 4: UploadView receives the name and calls Firestore

**Source:** `UploadView` — the `onSubmit` closure is:

```swift
onSubmit: { _, activityName in
    guard let teamId = firestoreService.currentTeamId else { throw UploadError.noTeam }
    try await firestoreService.submitProof(
        teamId: teamId,
        image: image,
        activityName: activityName   // <-- this is the 2nd argument from Step 3
    )
    dismiss()
}
```

So `activityName` in this closure is exactly the `capturedName` passed from ConfirmPhotoView.

**Check:** Add a temporary print at the start of this closure (e.g. `print("DEBUG UploadView onSubmit activityName: \(activityName)")`). When you tap "Send Proof", does the console show `activityName: swim`?

- If **NO** → The problem is Step 4: the closure is not receiving the same string ConfirmPhotoView sent.
- If **YES** → Go to Step 5.

---

## Step 5: FirestoreService receives the name and writes it

**Source:** `FirestoreService.submitProof(teamId:image:activityName:)`:

1. Does `let activityNameCopy = String(activityName)`.
2. Trims and uses fallback: `let finalActivityName = nameToStore.isEmpty ? "Proof" : nameToStore`.
3. Writes the submission with `"activityName": finalActivityName` in `submissionData` and calls `setData(submissionData)` on the submission document.

**Check:** Add a temporary print at the start of `submitProof` (e.g. `print("DEBUG submitProof activityName: \(activityName)")`) and one right before `setData` (e.g. `print("DEBUG submitProof finalActivityName: \(finalActivityName)")`). Do you see `activityName: swim` and `finalActivityName: swim`?

- If **NO** (e.g. empty or "Proof") → The problem is Step 5: the parameter is wrong by the time it reaches `submitProof`, or the trim/fallback is replacing it.
- If **YES** but Firebase still doesn’t have "swim" → The write path is correct; the issue may be which document you’re looking at (path/date) or something overwriting the doc after (e.g. security rules, another client, or a Cloud Function).

---

## Summary chain

```
Firestore goals (or fallback) 
  → UploadView.activityOptions [ActivityOption with .name]
  → CameraScreen carousel selection
  → onCapture(image, activity) → UploadView.selectedActivity
  → ConfirmPhotoView(activity: selectedActivity) → selectedActivity.name shown as "Submitting proof for X"
  → Tap "Send Proof" → capturedName = selectedActivity.name → onSubmit(_, capturedName)
  → UploadView onSubmit(_, activityName) → submitProof(..., activityName: activityName)
  → FirestoreService.submitProof(activityName:) → finalActivityName → setData(["activityName": finalActivityName])
```

Tell me which step is the first one where the value is wrong (or where you’re unsure), and we can fix that exact place.
