//
//  LiftSheetView.swift
//  Pact
//
//  Draggable bottom panel with 3 snap positions + spring physics + haptics.
//

import SwiftUI
import FirebaseAuth

// MARK: - Snap Position

enum SheetPosition: CaseIterable {
    case peek   // 38% of screen height
    case mid    // 62%
    case full   // 95%

    func height(screenHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek:  return screenHeight * 0.40
        case .mid:   return screenHeight * 0.63
        case .full:  return screenHeight * 0.95
        }
    }
}

// MARK: - LiftSheetView

struct LiftSheetView: View {
    // Data
    let members: [TeamMember]
    let submissions: [Submission]
    let userActivities: [TeamActivity]
    let recentSubmissions: [[String: Any]]
    let teamId: String
    let onVote: (String, String) -> Void      // submissionId, vote
    let onSubmitTap: () -> Void

    @Binding var position: SheetPosition

    @GestureState private var dragOffset: CGFloat = 0
    @State private var contentOpacity: [SheetPosition: Double] = [.peek: 1, .mid: 0, .full: 0]

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let screenH = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let targetH = position.height(screenHeight: screenH)
            let currentH = max(targetH - dragOffset, SheetPosition.peek.height(screenHeight: screenH))

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color(white: 0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Header: team status
                peekContent
                    .padding(.horizontal, 24)

                // Mid content (goal card + submission)
                if position == .mid || position == .full {
                    midContent
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .opacity(contentOpacity[.mid] ?? 0)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Full content (momentum + vote queue)
                if position == .full {
                    fullContent
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .opacity(contentOpacity[.full] ?? 0)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: currentH)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 28,
                    style: .continuous
                )
                .fill(Color.pactSurface)
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        handleDragEnd(velocity: value.predictedEndTranslation.height,
                                      displacement: value.translation.height,
                                      screenH: screenH)
                    }
            )
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: position)
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: dragOffset == 0)
        }
    }

    // MARK: - Peek Content (always visible)

    private var peekContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Team")
                    .font(PactFont.sectionTitle)
                    .foregroundStyle(Color.pactTextPrimary)
                Spacer()
                let approvedCount = submissions.filter { $0.isApproved }.count
                Text("\(approvedCount) of \(members.count) done")
                    .font(PactFont.caption)
                    .foregroundStyle(Color.pactTextSecond)
            }

            TeamStatusRowView(members: members, submissions: submissions)
                .padding(.horizontal, -24)  // bleed to edges
        }
    }

    // MARK: - Mid Content

    private var midContent: some View {
        VStack(spacing: 12) {
            ForEach(userActivities) { activity in
                let myUID = Auth.auth().currentUser?.uid ?? ""
                let sub = submissions.first {
                    $0.submitterUid == myUID && $0.activityId == activity.id
                }
                DailyGoalCardView(
                    activity: activity,
                    submission: sub,
                    onSubmitTap: onSubmitTap
                )
            }
        }
    }

    // MARK: - Full Content

    private var fullContent: some View {
        VStack(spacing: 20) {
            Divider()
                .background(Color.pactSurface2)

            Momentum7DayView(
                members: members,
                recentSubmissions: recentSubmissions
            )

            let pendingVotes = pendingSubmissions
            if !pendingVotes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Vote Queue")
                        .font(PactFont.sectionTitle)
                        .foregroundStyle(Color.pactTextPrimary)

                    ForEach(pendingVotes) { sub in
                        VoteQueueCardView(
                            submission: sub,
                            teamId: teamId
                        ) { vote in
                            onVote(sub.id, vote)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var pendingSubmissions: [Submission] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return submissions.filter {
            $0.submitterUid != uid &&
            $0.status == "pending" &&
            !$0.voterIds.contains(uid)
        }
    }

    private func handleDragEnd(velocity: CGFloat, displacement: CGFloat, screenH: CGFloat) {
        let velocityThreshold: CGFloat = 400
        let displacementThreshold: CGFloat = 80

        let draggedUp = velocity < -velocityThreshold || displacement < -displacementThreshold
        let draggedDown = velocity > velocityThreshold || displacement > displacementThreshold

        let newPosition: SheetPosition
        switch position {
        case .peek:
            newPosition = draggedUp ? .mid : .peek
        case .mid:
            newPosition = draggedUp ? .full : (draggedDown ? .peek : .mid)
        case .full:
            newPosition = draggedDown ? .mid : .full
        }

        if newPosition != position {
            feedbackGenerator.impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                position = newPosition
            }
            updateContentOpacity(for: newPosition)
        }
    }

    private func updateContentOpacity(for pos: SheetPosition) {
        withAnimation(.easeInOut(duration: 0.25)) {
            contentOpacity[.mid]  = (pos == .mid || pos == .full) ? 1 : 0
            contentOpacity[.full] = pos == .full ? 1 : 0
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.pactBackground.ignoresSafeArea()
        LiftSheetView(
            members: [],
            submissions: [],
            userActivities: [],
            recentSubmissions: [],
            teamId: "preview",
            onVote: { _, _ in },
            onSubmitTap: {},
            position: .constant(.peek)
        )
    }
}
