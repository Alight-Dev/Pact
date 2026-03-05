import SwiftUI
import FirebaseAuth

struct ConfirmPhotoView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    let image: UIImage
    let activities: [ActivityOption]
    let onRetake: () -> Void
    /// Called after a successful submit so the parent can dismiss.
    let onSuccess: () -> Void

    @State private var selectedActivity: ActivityOption
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showActivityPicker = false

    init(
        image: UIImage,
        activity: ActivityOption,
        activities: [ActivityOption],
        onRetake: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        self.image = image
        self.activities = activities
        self.onRetake = onRetake
        self.onSuccess = onSuccess
        _selectedActivity = State(initialValue: activity)
    }

    var body: some View {
        GeometryReader { geo in
            let safeW = geo.size.width
            let safeH = geo.size.height
            let bottomInset = geo.safeAreaInsets.bottom
            let topInset = geo.safeAreaInsets.top

            ZStack {
                // Full-screen photo
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: safeW, height: safeH)
                    .clipped()
                    .ignoresSafeArea()

                // Subtle vignette
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0.0),
                        .init(color: .clear,               location: 0.4),
                        .init(color: .clear,               location: 0.6),
                        .init(color: .black.opacity(0.5),  location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: safeW, height: safeH)
                .ignoresSafeArea()

                // Overlay content — fixed frame so layout is predictable
                VStack(spacing: 0) {
                    // Nav bar: fixed height, lowered further from top
                    navBar(safeWidth: safeW)
                        .frame(width: safeW, height: 44)
                        .padding(.top, max(52, topInset + 36))

                    Spacer(minLength: 0)

                    // Activity context + Send Proof button
                    VStack(spacing: 16) {
                        // Text so user knows which activity they're submitting for
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Submitting proof for")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.75))
                            Text(selectedActivity.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Your team will vote to approve")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                        bottomBar
                            .frame(width: safeW - 48, height: 56)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(24, bottomInset + 8))
                }
                .frame(width: safeW, height: safeH)

                // Custom upload-error overlay (matches app UI: white card, black text)
                if uploadError != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { uploadError = nil }

                    VStack(spacing: 0) {
                        Text("Upload Failed")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.top, 20)
                            .padding(.horizontal, 24)

                        Text(uploadError ?? "")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(white: 0.45))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal, 24)

                        Button {
                            uploadError = nil
                        } label: {
                            Text("OK")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: 280)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.container)
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.2), value: uploadError != nil)
        .sheet(isPresented: $showActivityPicker) {
            ActivitySelectionSheet(
                activities: activities,
                selectedActivity: $selectedActivity
            ) {
                showActivityPicker = false
            }
        }
    }

    // MARK: - Nav bar: Retake left, title centered, activity right (no overflow)

    private func navBar(safeWidth: CGFloat) -> some View {
        ZStack {
            HStack(spacing: 0) {
                // Left: Retake
                Button(action: onRetake) {
                    Text("Retake")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.leading, 20)

                Spacer(minLength: 0)

                // Right: activity chip — tap to change activity
                Button {
                    showActivityPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: selectedActivity.iconName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(selectedActivity.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: min(100, (safeWidth - 120) / 2))
                .padding(.trailing, 20)
            }

            // Center title — truly centered regardless of left/right widths
            Text("Confirm")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: safeWidth, height: 44)
    }

    // MARK: - Bottom: one button, fixed size

    private var bottomBar: some View {
        Button {
            isUploading = true
            let capturedName = String(selectedActivity.name)
            let activityId = selectedActivity.id
            guard let teamId = firestoreService.currentTeamId else {
                uploadError = UploadError.noTeam.errorDescription
                isUploading = false
                return
            }
            // Per-activity re-submission guard: don't submit if already submitted for this activity today
            guard let uid = Auth.auth().currentUser?.uid else {
                isUploading = false
                return
            }
            let alreadySubmitted = firestoreService.mappedSubmissions.contains { sub in
                sub.submitterUid == uid && sub.activityId == activityId
            }
            if alreadySubmitted {
                uploadError = "You already submitted proof for \(selectedActivity.name) today."
                isUploading = false
                return
            }
            Task {
                do {
                    try await firestoreService.submitProof(teamId: teamId, image: image, activityName: capturedName, activityId: selectedActivity.id)
                    onSuccess()
                } catch {
                    uploadError = error.localizedDescription
                    isUploading = false
                }
            }
        } label: {
            ZStack {
                HStack(spacing: 8) {
                    Image(systemName: selectedActivity.iconName)
                        .font(.system(size: 17, weight: .semibold))
                    Text("Send Proof")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Color(white: 0.18))
                .opacity(isUploading ? 0 : 1)

                if isUploading {
                    ProgressView()
                        .tint(Color(white: 0.18))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
            )
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }
}

// MARK: - ActivitySelectionSheet

private struct ActivitySelectionSheet: View {
    let activities: [ActivityOption]
    @Binding var selectedActivity: ActivityOption
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(activities) { option in
                Button {
                    selectedActivity = option
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(.black)
                            .background(Circle().fill(Color.white.opacity(0.9)))

                        Text(option.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)

                        Spacer()

                        if option == selectedActivity {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDone()
                        dismiss()
                    }
                    .foregroundStyle(.black)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                }
            }
        }
    }
}

#Preview {
    ConfirmPhotoView(
        image: UIImage(systemName: "photo")!,
        activity: ActivityOption(id: "run", name: "Morning Run", iconName: "figure.run"),
        activities: [
            ActivityOption(id: "run", name: "Morning Run", iconName: "figure.run"),
            ActivityOption(id: "study", name: "Study", iconName: "book.fill")
        ],
        onRetake: {},
        onSuccess: {}
    )
    .environmentObject(FirestoreService())
}
