//
//  ForgePactView.swift
//  Pact
//

import SwiftUI
import FirebaseAuth

struct ForgePactView: View {
    var onContinue: () -> Void

    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isAgreeing = false
    @State private var agreeError: String?
    /// Short delay before "I Agree" becomes clickable so the user has time to read the screen.
    @State private var agreeButtonUnlocked = false

    private var teamId: String? { firestoreService.currentTeamId }
    private var teamName: String {
        firestoreService.currentTeamName
            ?? firestoreService.currentTeam?["name"] as? String
            ?? "Your Shield"
    }
    private var goalId: String? {
        firestoreService.currentTeam?["currentGoalId"] as? String
    }
    private var activities: [TeamActivity] {
        firestoreService.teamActivities
    }
    private var forgeState: GoalForgeState? { firestoreService.currentGoalForgeState }
    private var memberCount: Int {
        (firestoreService.currentTeam?["memberCount"] as? Int) ?? max(1, firestoreService.members.count)
    }
    private var agreedCount: Int { forgeState?.agreedCount ?? 0 }
    private var hasCurrentUserAgreed: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return forgeState?.agreedMemberIds.contains(uid) ?? false
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if goalId == nil && firestoreService.currentTeam != nil {
                loadingOrSkipView
            } else if goalId == nil {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContent
            }
        }
        .preferredColorScheme(.light)
    }

    private var loadingOrSkipView: some View {
        VStack(spacing: 24) {
            Text("Loading your Pact…")
                .font(.system(size: 17))
                .foregroundStyle(Color(white: 0.55))
            Button("Go to Pact", action: onContinue)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.black))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        GeometryReader { geo in
            let isCompact = geo.size.height < 620
            VStack(spacing: 0) {
                // Full-page splash: serious, bold header
                VStack(spacing: 0) {
                    Text("FORGE YOUR PACT")
                        .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                        .kerning(2.5)
                        .foregroundStyle(Color(white: 0.45))
                        .padding(.top, verticalSizeClass == .compact ? 24 : 52)

                    Text(teamName)
                        .font(.system(size: isCompact ? 32 : 40, weight: .black))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)

                    Text("One agreement binds the whole team.\nNo backing out once you commit.")
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)

                // Daily commitment: all activities, scrollable when more than 5
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAILY COMMITMENT")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.horizontal, 24)

                    if activities.count > 5 {
                        ScrollView(.vertical, showsIndicators: true) {
                            dailyCommitmentCards
                                .padding(.bottom, 8)
                        }
                        .frame(maxHeight: 280)
                    } else {
                        dailyCommitmentCards
                    }
                }
                .padding(.top, isCompact ? 20 : 36)

                // Live counter + clarify they can leave anytime
                Text("\(agreedCount) of \(memberCount) members have agreed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.45))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                Text("You can enter Pact now; the challenge starts when everyone has agreed.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)

                if let err = agreeError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                }

                Spacer(minLength: 24)
            }

            // Bottom: fixed full-width CTA(s)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                bottomButtons
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            agreeButtonUnlocked = false
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { agreeButtonUnlocked = true }
            }
        }
    }

    @ViewBuilder
    private var dailyCommitmentCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(activities) { activity in
                activityCard(activity)
            }
        }
        .padding(.horizontal, 24)
    }

    private func activityCard(_ activity: TeamActivity) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 48, height: 48)
                Image(systemName: activity.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                if !activity.activityDescription.isEmpty {
                    Text(activity.activityDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.5))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var bottomButtons: some View {
        VStack(spacing: 14) {
            if !hasCurrentUserAgreed {
                Button {
                    agree()
                } label: {
                    Group {
                        if isAgreeing {
                            ProgressView().tint(.white)
                        } else {
                            Text("I AGREE")
                                .font(.system(size: 18, weight: .bold))
                                .kerning(1.2)
                        }
                    }
                    .foregroundStyle(agreeButtonUnlocked ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Capsule().fill(Color.black.opacity(agreeButtonUnlocked ? 1 : 0.5)))
                }
                .disabled(isAgreeing || !agreeButtonUnlocked)
                .buttonStyle(.plain)
            }
            Button(action: onContinue) {
                Text("Enter Pact")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(hasCurrentUserAgreed ? .white : Color(white: 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, hasCurrentUserAgreed ? 20 : 0)
                    .background(hasCurrentUserAgreed ? Capsule().fill(Color.black) : Capsule().fill(Color.clear))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 40)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: -4)
        )
    }

    private func agree() {
        guard let teamId = teamId, let goalId = goalId else { return }
        agreeError = nil
        isAgreeing = true
        Task {
            do {
                try await firestoreService.forgePact(teamId: teamId, goalId: goalId)
                await MainActor.run { isAgreeing = false }
            } catch {
                await MainActor.run {
                    agreeError = error.localizedDescription
                    isAgreeing = false
                }
            }
        }
    }
}

#Preview {
    ForgePactView(onContinue: {})
        .environmentObject(FirestoreService())
}
