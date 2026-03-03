import SwiftUI

struct ConfirmPhotoView: View {
    let image: UIImage
    let activities: [ActivityOption]
    let onRetake: () -> Void
    let onSubmit: (ActivityOption) async throws -> Void

    @State private var selectedActivity: ActivityOption
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showActivityPicker = false

    init(
        image: UIImage,
        activity: ActivityOption,
        activities: [ActivityOption],
        onRetake: @escaping () -> Void,
        onSubmit: @escaping (ActivityOption) async throws -> Void
    ) {
        self.image = image
        self.activities = activities
        self.onRetake = onRetake
        self.onSubmit = onSubmit
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
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.container)
        .statusBarHidden(true)
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
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
            Task {
                do {
                    try await onSubmit(selectedActivity)
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
        onSubmit: { _ in }
    )
}
