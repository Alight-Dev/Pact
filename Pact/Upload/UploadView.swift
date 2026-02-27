import SwiftUI
import AVFoundation
import UIKit

struct UploadProofView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .camera
    @State private var selectedImage: UIImage? = nil
    @State private var selectedActivityID: String? = nil
    @State private var pickerErrorMessage: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            // Content layer — post-photo or pre-photo
            if let image = selectedImage {
                postPhotoContent(image: image)
            } else {
                // Pre-photo state: prompt user to upload proof
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 10) {
                        Text("Upload Proof")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)

                        Text("Submit live proof to verify today’s goal.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer()

                    Button {
                        handleUploadProofTapped()
                    } label: {
                        Text("Upload Proof")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Back button always on top — rendered last in ZStack so it’s never blocked
            HStack(spacing: 8) {
                Button(action: {
                    if selectedImage != nil {
                        // Step back: clear photo, return to pre-photo state
                        selectedImage = nil
                        selectedActivityID = nil
                    } else {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        // Image picker sheet (camera only)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSource) { image in
                if let image {
                    // Reset activity selection when new image chosen
                    selectedImage = image
                    selectedActivityID = nil
                } else {
                    pickerErrorMessage = "We couldn’t load that photo. Please try again."
                }
            }
        }
        // Error alert for picker failures
        .alert("Upload Failed", isPresented: Binding(
            get: { pickerErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    pickerErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(pickerErrorMessage ?? "")
        }
    }

    private func handleUploadProofTapped() {
        // Prefer camera; if unavailable (e.g. simulator), show an error.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePickerSource = .camera
            showImagePicker = true
        } else {
            pickerErrorMessage = "Camera is not available on this device."
        }
    }
}

#Preview {
    UploadProofView()
}

// MARK: - UploadProofView Post-Photo Content

extension UploadProofView {
    private struct ActivityOption: Identifiable, Hashable {
        var id: String { name }   // stable across re-renders
        let name: String
        let iconName: String
    }

    // TODO: replace with real activities from your model
    private var activityOptions: [ActivityOption] {
        [
            ActivityOption(name: "Morning Run", iconName: "figure.run"),
            ActivityOption(name: "Study", iconName: "book.fill"),
            ActivityOption(name: "Meditate", iconName: "brain.head.profile"),
            ActivityOption(name: "Gym", iconName: "dumbbell.fill"),
            ActivityOption(name: "Reading", iconName: "text.book.closed.fill"),
            ActivityOption(name: "Practice", iconName: "music.note"),
        ]
    }

    private var canSubmit: Bool {
        selectedImage != nil && selectedActivityID != nil
    }

    @ViewBuilder
    private func postPhotoContent(image: UIImage) -> some View {
        VStack(spacing: 24) {
            // Space for the Back button overlay (always 54pt tall)
            Color.clear.frame(height: 54)

            // Image preview
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)

            // Activity selection grid
            VStack(spacing: 16) {
                Text("Choose Activity")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let columns = [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(activityOptions) { activity in
                        let isSelected = selectedActivityID == activity.id

                        Button {
                            selectedActivityID = activity.id
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: activity.iconName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.white : Color(white: 0.45))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(isSelected ? Color.black : Color(white: 0.90))
                                            .shadow(color: isSelected ? Color.black.opacity(0.22) : .clear,
                                                    radius: 10, x: 0, y: 4)
                                    )
                                    .scaleEffect(isSelected ? 1.07 : 1.0)

                                Text(activity.name)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .black : Color(white: 0.55))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Submit button
            Button {
                // TODO: fire proof submission to backend before dismissing
                dismiss()
            } label: {
                Text(canSubmit ? "Submit" : "Upload Proof")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canSubmit ? Color.white : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(canSubmit ? Color.black : Color(white: 0.9))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - UIKit Image Picker Wrapper

private struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            completion(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
            picker.dismiss(animated: true)
        }
    }
}
