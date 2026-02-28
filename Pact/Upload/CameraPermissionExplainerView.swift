import SwiftUI

struct CameraPermissionExplainerView: View {
    var onEnable: () -> Void
    var onCancel: () -> Void

    @State private var viewfinderScale: CGFloat = 0.85
    @State private var viewfinderOpacity: Double = 0
    @State private var scanOffset: CGFloat = -80
    @State private var iconScale: CGFloat = 1.0
    @State private var bracketsOpacity: Double = 0
    @State private var rowOpacity: [Double] = [0, 0, 0]
    @State private var rowOffset: [CGFloat] = [12, 12, 12]
    @State private var dashPhase: CGFloat = 0

    private let green = Color(red: 0.13, green: 0.77, blue: 0.44)

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(white: 0.85))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Dismiss button
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(white: 0.93)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            // Hero — animated viewfinder
            viewfinderHero
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // Title + subtitle
            VStack(spacing: 8) {
                Text("Camera Required")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
                Text("We verify every submission live. No gallery uploads — your team deserves real proof.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.50))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            // Feature rows
            VStack(spacing: 0) {
                featureRow(icon: "camera.fill",
                           title: "Live capture only",
                           subtitle: "A fresh photo every time — no old uploads",
                           index: 0)
                featureRow(icon: "checkmark.shield.fill",
                           title: "Verified by your team",
                           subtitle: "Teammates vote to approve your proof",
                           index: 1)
                featureRow(icon: "lock.fill",
                           title: "Private to your Shield",
                           subtitle: "Only your Shield members can see your proof",
                           index: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // CTA buttons
            VStack(spacing: 12) {
                Button(action: onEnable) {
                    Text("Enable Camera")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black))
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Not Now")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .onAppear { startAnimations() }
    }

    // MARK: - Viewfinder Hero (260×180)

    private var viewfinderHero: some View {
        ZStack {
            // Dashed border
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    green.opacity(0.6),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6], dashPhase: dashPhase)
                )
                .frame(width: 260, height: 180)

            // Scan line clipped to viewfinder interior
            LinearGradient(
                colors: [green.opacity(0.0), green.opacity(0.55), green.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 240, height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .offset(y: scanOffset)
            .frame(width: 240, height: 180, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Corner brackets
            cornerBrackets
                .opacity(bracketsOpacity)

            // Camera icon pulse
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color(white: 0.15))
                .scaleEffect(iconScale)
        }
        .frame(width: 260, height: 180)
        .scaleEffect(viewfinderScale)
        .opacity(viewfinderOpacity)
    }

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        ZStack {
            bracketShape(rotation: 0)   .offset(x: -106, y: -75)   // top-left
            bracketShape(rotation: 90)  .offset(x:  106, y: -75)   // top-right
            bracketShape(rotation: 180) .offset(x:  106, y:  75)   // bottom-right
            bracketShape(rotation: 270) .offset(x: -106, y:  75)   // bottom-left
        }
    }

    private func bracketShape(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 22))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 22, y: 0))
        }
        .stroke(green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .frame(width: 22, height: 22)
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, subtitle: String, index: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(green.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.55))
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .opacity(rowOpacity[index])
        .offset(y: rowOffset[index])
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
            viewfinderScale = 1.0
            viewfinderOpacity = 1.0
        }

        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false).delay(0.1)) {
            scanOffset = 80
        }

        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false).delay(0.1)) {
            dashPhase = -56
        }

        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.1)) {
            iconScale = 0.97
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.25)) {
            bracketsOpacity = 1.0
        }

        let rowDelays: [Double] = [0.35, 0.47, 0.59]
        for i in 0..<3 {
            withAnimation(.easeOut(duration: 0.4).delay(rowDelays[i])) {
                rowOpacity[i] = 1.0
                rowOffset[i] = 0
            }
        }
    }
}

#Preview {
    CameraPermissionExplainerView(
        onEnable: { print("Enable tapped") },
        onCancel: { print("Cancel tapped") }
    )
}
