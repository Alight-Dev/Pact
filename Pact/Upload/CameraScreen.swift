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

        let usedFrontCamera = isFrontCamera
        DispatchQueue.main.async { [weak self] in
            let corrected = image.normalizedForDisplay(mirrorIfFrontCamera: usedFrontCamera)
            self?.onPhotoCaptured?(corrected, activity)
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
    @State private var dragOffset: CGFloat = .zero
    @State private var transitionFlash: Bool = false

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

            // Transition vignette — radial dark pulse from edges on activity switch
            RadialGradient(
                colors: [.clear, .black.opacity(0.72)],
                center: .center,
                startRadius: 80,
                endRadius: 480
            )
            .ignoresSafeArea()
            .opacity(transitionFlash ? 1 : 0)
            .animation(.easeInOut(duration: 0.18), value: transitionFlash)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomControls
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let dx = value.translation.width
                    if dx < -50 { selectNext() }
                    else if dx > 50 { selectPrevious() }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
        )
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
        VStack(spacing: 0) {
            if !activities.isEmpty {
                // Strip + fixed side previews layered together
                ZStack {
                    activityStrip
                    sideActivityPreviews
                }
                .padding(.bottom, 28)
            }
            captureRow
        }
        .padding(.bottom, 48)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Activity Strip (full-width paged)

    private var activityStrip: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let currentIdx = activities.firstIndex(where: { $0.id == selectedActivityID }) ?? 0

            HStack(spacing: 0) {
                ForEach(Array(activities.enumerated()), id: \.element.id) { idx, activity in
                    let d = CGFloat(idx - currentIdx) + dragOffset / w
                    let absD = min(abs(d), 1.5)
                    // Only render the center card content — neighbors are handled by sideActivityPreviews
                    let scale: CGFloat = max(0.68, 1.0 - absD * 0.3)
                    let opacity: CGFloat = absD < 0.15 ? 1.0 : max(0, 1.0 - absD * 3.5)

                    VStack(spacing: 9) {
                        Image(systemName: activity.iconName)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(.white)
                        Text(activity.name)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .frame(width: w)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    // Scale punch on switch (driven by activitySwitchID change)
                    .scaleEffect(transitionFlash ? 0.88 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: transitionFlash)
                }
            }
            .offset(x: -CGFloat(currentIdx) * w + dragOffset)
        }
        .frame(height: 88)
        .clipped()
        .allowsHitTesting(false)
    }

    // MARK: - Side Activity Previews (always visible, flanking the center)

    private var sideActivityPreviews: some View {
        let currentIdx = activities.firstIndex(where: { $0.id == selectedActivityID }) ?? 0
        let prevActivity = currentIdx > 0 ? activities[currentIdx - 1] : nil
        let nextActivity = currentIdx < activities.count - 1 ? activities[currentIdx + 1] : nil

        // Boost opacity as the user drags toward each side
        let halfScreen: CGFloat = 180
        let leftBoost  = max(0, min(1, dragOffset / halfScreen))   // 0→1 as dragging right (prev)
        let rightBoost = max(0, min(1, -dragOffset / halfScreen))  // 0→1 as dragging left (next)

        return HStack(alignment: .center) {
            // Left — previous activity
            Group {
                if let prev = prevActivity {
                    VStack(spacing: 5) {
                        Image(systemName: prev.iconName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                        Text(prev.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .opacity(0.42 + leftBoost * 0.42)
                    .scaleEffect(0.88 + leftBoost * 0.06)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: 80, alignment: .leading)
            .padding(.leading, 22)

            Spacer()

            // Right — next activity
            Group {
                if let next = nextActivity {
                    VStack(spacing: 5) {
                        Image(systemName: next.iconName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                        Text(next.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .opacity(0.42 + rightBoost * 0.42)
                    .scaleEffect(0.88 + rightBoost * 0.06)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: 80, alignment: .trailing)
            .padding(.trailing, 22)
        }
        .frame(height: 88)
        .allowsHitTesting(false)
    }

    // MARK: - Swipe Helpers

    private func selectNext() {
        guard let idx = activities.firstIndex(where: { $0.id == selectedActivityID }),
              idx < activities.count - 1 else { return }
        selectedActivityID = activities[idx + 1].id
        triggerTransitionFlash()
    }

    private func selectPrevious() {
        guard let idx = activities.firstIndex(where: { $0.id == selectedActivityID }),
              idx > 0 else { return }
        selectedActivityID = activities[idx - 1].id
        triggerTransitionFlash()
    }

    private func triggerTransitionFlash() {
        transitionFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            transitionFlash = false
        }
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

// MARK: - UIImage orientation and mirroring for review

private extension UIImage {
    /// Returns a new image with orientation normalized to .up and optionally mirrored horizontally
    /// so the review screen matches what the user saw in the camera preview (e.g. selfie view).
    func normalizedForDisplay(mirrorIfFrontCamera: Bool) -> UIImage {
        let normalized = normalizedOrientation()
        guard mirrorIfFrontCamera else { return normalized }
        return normalized.mirroredHorizontally() ?? normalized
    }

    /// Redraws the image so its pixel data has orientation .up (fixes EXIF-based rotation/flip).
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: rect)
        }
    }

    /// Returns a new image flipped horizontally (mirror).
    func mirroredHorizontally() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let flipped = renderer.image { ctx in
            ctx.cgContext.translateBy(x: size.width, y: 0)
            ctx.cgContext.scaleBy(x: -1, y: 1)
            draw(at: .zero)
        }
        return flipped
    }
}

