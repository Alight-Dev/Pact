import SwiftUI

struct ConfirmPhotoView: View {
    let image: UIImage
    let activity: ActivityOption
    let onRetake: () -> Void
    let onSubmit: () async throws -> Void

    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        ZStack {
            // Full-screen photo background
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Dark gradient — clear at top, near-solid black at bottom
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.90), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Bottom panel pushed down by Spacer — respects safe area automatically
            VStack(spacing: 0) {
                Spacer()
                bottomPanel
            }
        }
        .statusBarHidden(true)
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Activity row
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 48, height: 48)
                    Image(systemName: activity.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Confirm your proof")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(activity.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)

            // Retake / Submit buttons
            HStack(spacing: 12) {
                Button(action: onRetake) {
                    Text("Retake")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    isUploading = true
                    Task {
                        do {
                            try await onSubmit()
                        } catch {
                            uploadError = error.localizedDescription
                            isUploading = false
                        }
                    }
                } label: {
                    ZStack {
                        Text("Submit")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .opacity(isUploading ? 0 : 1)
                        if isUploading {
                            ProgressView().tint(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                }
                .buttonStyle(.plain)
                .disabled(isUploading)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 28) // space above home indicator
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ConfirmPhotoView(
        image: UIImage(systemName: "photo")!,
        activity: ActivityOption(id: "run", name: "Morning Run", iconName: "figure.run"),
        onRetake: {},
        onSubmit: {}
    )
}
