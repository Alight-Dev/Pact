//
//  JoinShieldActivitiesView.swift
//  Pact
//

import SwiftUI

struct JoinShieldActivitiesView: View {
    var onContinue: () -> Void

    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedIds: Set<String> = []
    @State private var isSaving = false
    @State private var saveError: String?

    private var canContinue: Bool {
        !selectedIds.isEmpty && !isSaving
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose Your Activities")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)

                            Text("Select at least one activity to commit to.\nYour shield depends on everyone showing up.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.55))
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)

                        // MARK: Activity cards
                        LazyVStack(spacing: 12) {
                            ForEach(firestoreService.teamActivities) { activity in
                                activityCard(activity)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 28)

                        if let error = saveError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                        }

                        Spacer(minLength: 120)
                    }
                }
            }

            // MARK: CTA
            Button {
                save()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Join Shield")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(canContinue ? .white : Color.black.opacity(0.30))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(canContinue ? Color.black : Color(red: 0.88, green: 0.88, blue: 0.90))
                )
            }
            .disabled(!canContinue)
            .animation(.easeInOut(duration: 0.2), value: canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Activity Card

    @ViewBuilder
    private func activityCard(_ activity: TeamActivity) -> some View {
        let isSelected = selectedIds.contains(activity.id)

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if isSelected {
                    selectedIds.remove(activity.id)
                } else {
                    selectedIds.insert(activity.id)
                }
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : Color(white: 0.93))
                        .frame(width: 48, height: 48)

                    Image(systemName: activity.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .black)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)

                    if !activity.activityDescription.isEmpty {
                        Text(activity.activityDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color(white: 0.55))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .white : Color(white: 0.78))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.black : Color(white: 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.black.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        guard let teamId = firestoreService.currentTeamId else { return }
        isSaving = true
        saveError = nil

        Task {
            do {
                try await firestoreService.updateOptedInActivities(
                    teamId: teamId,
                    activityIds: Array(selectedIds)
                )
                await MainActor.run { onContinue() }
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    JoinShieldActivitiesView(onContinue: {})
        .environmentObject(FirestoreService())
}
