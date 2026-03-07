//
//  TeamWelcomeView.swift
//  Pact
//

import SwiftUI

struct TeamWelcomeView: View {
    let teamName: String
    let inviteCode: String
    let onFinished: () -> Void

    @State private var logoOffsetY: CGFloat = 0
    @State private var logoSize: CGFloat = 200
    @State private var showContent: Bool = false
    @State private var screenHeight: CGFloat = 1000
    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: CGFloat = 0
    @State private var showShareSheet = false
    @State private var codeCopied = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Logo — springs from center to upper area, matching onboarding feel
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .offset(y: logoOffsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if showContent {
                VStack(spacing: 0) {
                    // Space reserved for the risen logo
                    Spacer()
                        .frame(height: screenHeight * 0.26)

                    // Center copy
                    VStack(spacing: 8) {
                        // Badge
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Shield Created")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(white: 0.45))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(white: 0.93)))

                        Text("Welcome to\nPact.")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)

                        if !teamName.isEmpty {
                            Text(teamName)
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.55))
                                .padding(.top, 2)
                        }
                    }

                    Spacer()

                    // Bottom actions
                    VStack(spacing: 12) {
                        // Invite code card
                        VStack(spacing: 14) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("INVITE CODE")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.55))
                                        .kerning(0.8)

                                    Text(inviteCode)
                                        .font(.system(size: 30, weight: .black, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .kerning(5)
                                }

                                Spacer()

                                // Copy button
                                Button {
                                    UIPasteboard.general.string = inviteCode
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                        codeCopied = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { codeCopied = false }
                                    }
                                } label: {
                                    Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(codeCopied ? .white : .black)
                                        .frame(width: 42, height: 42)
                                        .background(
                                            Circle()
                                                .fill(codeCopied ? Color.black : Color(white: 0.91))
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: codeCopied)
                            }

                            Rectangle()
                                .fill(Color(white: 0.90))
                                .frame(height: 1)

                            Text("Share the code or send a link to invite teammates")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(white: 0.97))
                        )
                        .scaleEffect(cardScale)
                        .opacity(cardOpacity)

                        // Share Invite
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Share Invite")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                Capsule()
                                    .fill(Color(white: 0.94))
                                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                            )
                        }

                        // Go to Pact
                        Button(action: onFinished) {
                            Text("Go to Pact")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Capsule().fill(Color.black))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { screenHeight = geo.size.height }
            }
        }
        .onAppear {
            startAnimation()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareInviteSheet(inviteCode: inviteCode)
        }
        .preferredColorScheme(.light)
    }

    private func startAnimation() {
        // Phase 1: logo rises to upper area
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.80)) {
                logoOffsetY = -(screenHeight * 0.30)
                logoSize = 110
            }
        }
        // Phase 2: main content fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
            withAnimation(.easeOut(duration: 0.38)) {
                showContent = true
            }
        }
        // Phase 3: invite card springs into place
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
    }
}

// MARK: - ShareInviteSheet

private struct ShareInviteSheet: UIViewControllerRepresentable {
    let inviteCode: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let link = "pact://join/\(inviteCode)"
        UIActivityViewController(
            activityItems: [
                "Join my Pact Shield! 🛡️\nCode: \(inviteCode)\n\(link)",
                URL(string: link)!
            ],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    TeamWelcomeView(teamName: "Morning Crew", inviteCode: "X7K2P9", onFinished: {})
}
