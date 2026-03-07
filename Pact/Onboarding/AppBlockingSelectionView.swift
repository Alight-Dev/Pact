//
//  AppBlockingSelectionView.swift
//  Pact
//
//  App blocking setup screen shown after team creation (before TeamWelcomeView)
//  and after activity selection when joining (before HomeScreen).
//  Users open FamilyActivityPicker to choose which apps get locked each morning;
//  selection saved to UserDefaults. Skippable.
//

import FamilyControls
import ManagedSettings
import SwiftUI

struct AppBlockingSelectionView: View {
    let onContinue: () -> Void

    @State private var selection = FamilyActivitySelection()
    @State private var showFamilyPicker = false
    @State private var hasSelected = false

    private var authorizationGranted: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Icon
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "lock.iphone")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.black)
                    )

                // MARK: Heading
                VStack(spacing: 12) {
                    Text("Choose Apps to Block")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Select the apps that get locked each morning until your team approves your proof.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                Spacer()

                // MARK: Info card
                if authorizationGranted {
                    VStack(alignment: .leading, spacing: 18) {
                        infoRow(
                            icon: "lock.fill",
                            title: "Locked every morning",
                            body: "Apps are blocked at the start of each day until proof is approved."
                        )
                        infoRow(
                            icon: "checkmark.seal.fill",
                            title: "Unlocked by your team",
                            body: "A majority vote from teammates releases the lock."
                        )
                        infoRow(
                            icon: "gearshape.fill",
                            title: "You stay in control",
                            body: "Change your selections anytime in Settings."
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.97, green: 0.97, blue: 0.99))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                } else {
                    // Auth not granted — show muted message
                    VStack(spacing: 8) {
                        Image(systemName: "lock.slash")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.58))
                        Text("Screen Time access is required — you can enable it in Settings.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.58))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 0)

                // MARK: Selection summary (appears after picker)
                if hasSelected {
                    let appCount = selection.applications.count
                    let catCount = selection.categories.count
                    let parts = [
                        catCount > 0 ? "\(catCount) \(catCount == 1 ? "category" : "categories")" : nil,
                        appCount > 0 ? "\(appCount) \(appCount == 1 ? "app" : "apps")" : nil
                    ].compactMap { $0 }
                    let summaryText = parts.isEmpty ? "Selection saved" : parts.joined(separator: " · ") + " selected"

                    Text(summaryText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.38))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                        )
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // MARK: Buttons
                VStack(spacing: 14) {
                    if authorizationGranted {
                        // Choose / Change apps button
                        Button(action: { showFamilyPicker = true }) {
                            Text(hasSelected ? "Change Selection" : "Choose Apps →")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Capsule().fill(Color.black))
                        }
                        .buttonStyle(.plain)

                        // Continue button — only after selection
                        if hasSelected {
                            Button(action: saveAndContinue) {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(Capsule().fill(Color.black))
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    Button(action: onContinue) {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.2), value: hasSelected)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showFamilyPicker, onDismiss: {
            let hasApps = !selection.applications.isEmpty
            let hasCats = !selection.categories.isEmpty
            withAnimation {
                hasSelected = hasApps || hasCats
            }
        }) {
            NavigationStack {
                FamilyActivityPicker(selection: $selection)
                    .navigationTitle("Choose Apps")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showFamilyPicker = false }
                                .fontWeight(.semibold)
                        }
                    }
            }
        }
    }

    private func saveAndContinue() {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults(suiteName: AppBlockingService.appGroupID)?
                .set(data, forKey: AppBlockingService.selectionKey)
        }
        onContinue()
    }

    private func infoRow(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.96, green: 0.96, blue: 0.99))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                Text(body)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    AppBlockingSelectionView(onContinue: {})
}
