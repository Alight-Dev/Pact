import SwiftUI
import AVFoundation
import Combine

// MARK: - ActivityOption (shared across camera + confirm + coordinator)

struct ActivityOption: Identifiable, Hashable {
    let id: String
    let name: String
    let iconName: String
}

// MARK: - CameraViewModel

final class CameraViewModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    @Published var flashEnabled = false
    @Published var isFrontCamera = false

    /// Always set to the currently-centered carousel item before capture.
    var selectedActivity: ActivityOption?
    var onPhotoCaptured: ((UIImage, ActivityOption) -> Void)?

    private var currentInput: AVCaptureDeviceInput?

    // MARK: Session lifecycle

    func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: backCamera)
            else {
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
            }
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.setTorch(false)
            self.session.stopRunning()
        }
    }

    // MARK: Controls

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if !isFrontCamera && flashEnabled {
            settings.flashMode = .on
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: AVCaptureDevice.Position = self.isFrontCamera ? .back : .front

            guard
                let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                let newInput = try? AVCaptureDeviceInput(device: newCamera)
            else { return }

            self.session.beginConfiguration()
            if let current = self.currentInput { self.session.removeInput(current) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFrontCamera.toggle()
                if self.isFrontCamera {
                    self.flashEnabled = false
                }
            }
        }
    }

    func toggleFlash() {
        guard !isFrontCamera else { return }
        flashEnabled.toggle()
        setTorch(flashEnabled)
    }

    // MARK: Torch

    private func setTorch(_ on: Bool) {
        guard
            let device = currentInput?.device,
            device.hasTorch,
            device.isTorchAvailable
        else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        setTorch(false)

        guard
            error == nil,
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let activity = selectedActivity
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(image, activity)
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - CameraScreen

struct CameraScreen: View {
    let activities: [ActivityOption]
    var initialActivityId: String? = nil       // pre-selects a specific activity (e.g. for retakes)
    let onCapture: (UIImage, ActivityOption) -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel = CameraViewModel()
    @State private var selectedActivityID: String? = nil

    private var selectedActivity: ActivityOption? {
        activities.first { activity in
            if let id = selectedActivityID { return activity.id == id }
            return false
        } ?? activities.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewRepresentable(session: viewModel.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomControls
            }
        }
        .statusBarHidden(true)
        .onAppear {
            viewModel.onPhotoCaptured = { image, activity in
                onCapture(image, activity)
            }
            viewModel.configure()
            viewModel.start()
            if selectedActivityID == nil {
                // Pre-select the requested activity (retake flow), otherwise fall back to first
                let target = initialActivityId.flatMap { id in activities.first { $0.id == id } }
                    ?? activities.first
                if let target {
                    selectedActivityID = target.id
                    viewModel.selectedActivity = target
                }
            }
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: selectedActivityID) { _, newID in
            if let id = newID {
                viewModel.selectedActivity = activities.first { $0.id == id }
            } else {
                viewModel.selectedActivity = nil
            }
        }
        .onChange(of: activities) { _, newActivities in
            if selectedActivityID == nil, let first = newActivities.first {
                selectedActivityID = first.id
                viewModel.selectedActivity = first
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .buttonStyle(.plain)

            Spacer()

            Button { viewModel.toggleFlash() } label: {
                Image(systemName: viewModel.flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.flashEnabled ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .opacity(viewModel.isFrontCamera ? 0.35 : 1.0)
            .disabled(viewModel.isFrontCamera)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 24) {
            if !activities.isEmpty {
                activityCarousel
            }
            captureRow
        }
        .padding(.bottom, 48)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Activity Carousel

    private var activityCarousel: some View {
        GeometryReader { geo in
            let itemWidth: CGFloat = 116
            let spacing: CGFloat = 10
            let sidePad = (geo.size.width - itemWidth) / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(activities) { activity in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedActivityID = activity.id
                            }
                        } label: {
                            carouselPill(activity)
                                .frame(width: itemWidth)
                        }
                        .buttonStyle(.plain)
                        .id(activity.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sidePad)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedActivityID, anchor: .center)
        }
        .frame(height: 46)
    }

    private func carouselPill(_ activity: ActivityOption) -> some View {
        let isSelected = (selectedActivityID == activity.id)

        return HStack(spacing: 6) {
            Image(systemName: activity.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white)
            Text(activity.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .black : .white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(
            Capsule()
                .fill(isSelected ? Color.white : Color.white.opacity(0.18))
        )
        .scaleEffect(isSelected ? 1.06 : 0.94)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    // MARK: - Capture Row

    private var captureRow: some View {
        HStack {
            // Left — flip camera
            Button { viewModel.flipCamera() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .buttonStyle(.plain)

            Spacer()

            // Center — shutter (greyed out when no activities)
            Button {
                guard !activities.isEmpty else { return }
                viewModel.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .stroke(activities.isEmpty ? Color.gray : Color.white, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(activities.isEmpty ? Color.gray : Color.white)
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(.plain)
            .disabled(activities.isEmpty)
            .opacity(activities.isEmpty ? 0.6 : 1)

            Spacer()

            // Right — balance spacer
            Color.clear.frame(width: 54, height: 54)
        }
        .padding(.horizontal, 44)
    }
}

