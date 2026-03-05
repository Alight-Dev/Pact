import SwiftUI
import AVFoundation
import FirebaseAuth

// MARK: - UploadProofView (coordinator)

struct UploadProofView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var cameraReady = false
    @State private var showPermissionExplainer = false
    @State private var capturedImage: UIImage?
    @State private var selectedActivity: ActivityOption?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraReady {
                if let image = capturedImage, let activity = selectedActivity {
                    ConfirmPhotoView(
                        image: image,
                        activity: activity,
                        activities: activityOptions,
                        onRetake: {
                            capturedImage = nil
                            selectedActivity = nil
                        },
                        onSuccess: { dismiss() }
                    )
                    .transition(.opacity)
                } else if activityOptions.isEmpty {
                    AllSubmittedView(onDismiss: { dismiss() })
                } else {
                    CameraScreen(
                        activities: activityOptions,
                        onCapture: { image, activity in
                            capturedImage = image
                            selectedActivity = activity
                        },
                        onDismiss: { dismiss() }
                    )
                }
            }

            // Camera permission explainer overlay
            if showPermissionExplainer {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { /* don't dismiss on background tap */ }

                VStack {
                    Spacer()
                    CameraPermissionExplainerView(
                        onEnable: {
                            showPermissionExplainer = false
                            requestCameraPermission()
                        },
                        onCancel: {
                            showPermissionExplainer = false
                            dismiss()
                        }
                    )
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 32, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 32,
                        style: .continuous
                    ))
                    .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: -6)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showPermissionExplainer)
        .animation(.easeInOut(duration: 0.22), value: capturedImage != nil)
        .onAppear { checkCameraPermission() }
    }

    // MARK: - Activity options

    private var activityOptions: [ActivityOption] {
        let uid = Auth.auth().currentUser?.uid ?? ""

        // Exclude activities with a pending or approved submission today.
        // Rejected submissions reappear so the user can retry.
        let submittedAndActiveIds = Set(
            firestoreService.mappedSubmissions
                .filter { $0.submitterUid == uid && $0.status != "rejected" }
                .map { $0.activityId }
        )

        let live = firestoreService.userActivities
            .filter { !submittedAndActiveIds.contains($0.id) }
            .map { activity in
                let displayName = activity.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = displayName.isEmpty ? "Unnamed" : displayName
                return ActivityOption(id: activity.id, name: name, iconName: activity.iconName)
            }

        if !live.isEmpty { return live }

        // Fallback mock activities (no real submission IDs, so filtering is a no-op here)
        return [
            ActivityOption(id: "morning-run", name: "Morning Run",  iconName: "figure.run"),
            ActivityOption(id: "study",       name: "Study",        iconName: "book.fill"),
            ActivityOption(id: "meditate",    name: "Meditate",     iconName: "brain.head.profile"),
            ActivityOption(id: "gym",         name: "Gym",          iconName: "dumbbell.fill"),
            ActivityOption(id: "reading",     name: "Reading",      iconName: "text.book.closed.fill"),
            ActivityOption(id: "practice",    name: "Practice",     iconName: "music.note"),
        ]
    }

    // MARK: - Permission handling

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraReady = true
        case .notDetermined:
            showPermissionExplainer = true
        case .denied, .restricted:
            showPermissionExplainer = true
        @unknown default:
            showPermissionExplainer = true
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    cameraReady = true
                } else {
                    showPermissionExplainer = true
                }
            }
        }
    }
}

// MARK: - Upload error

enum UploadError: LocalizedError {
    case noTeam

    var errorDescription: String? {
        switch self {
        case .noTeam:
            return "No active team found. Please join or create a team first."
        }
    }
}

// MARK: - All Submitted View

private struct AllSubmittedView: View {
    let onDismiss: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("All submitted for today!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Activities will reappear here if a submission is rejected.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .padding(.top, 8)
            }
        }
    }
}

#Preview {
    UploadProofView()
        .environmentObject(FirestoreService())
}
