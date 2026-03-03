import SwiftUI
import AVFoundation

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
                        onSubmit: { chosenActivity in
                            guard let teamId = firestoreService.currentTeamId else {
                                throw UploadError.noTeam
                            }
                            try await firestoreService.submitProof(
                                teamId: teamId,
                                image: image,
                                activityName: chosenActivity.name
                            )
                            dismiss()
                        }
                    )
                    .transition(.opacity)
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
        let live = firestoreService.teamActivities.map {
            ActivityOption(id: $0.id, name: $0.name, iconName: $0.iconName)
        }
        if !live.isEmpty { return live }

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

#Preview {
    UploadProofView()
        .environmentObject(FirestoreService())
}
