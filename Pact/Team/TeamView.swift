//
//  TeamView.swift
//  Pact
//

import SwiftUI

// MARK: - Mock Data

private struct PendingSubmission: Identifiable {
    let id = UUID()
    let memberName: String
    let memberAvatarAsset: String
    let activityName: String
    let approvalsReceived: Int
    let approvalsRequired: Int
    // imageURL will replace placeholder once Firebase Storage is wired up
}

private let mockSubmissions: [PendingSubmission] = [
    PendingSubmission(memberName: "Alex", memberAvatarAsset: "avatar_alex", activityName: "Morning Gym", approvalsReceived: 1, approvalsRequired: 2),
    PendingSubmission(memberName: "Sarah", memberAvatarAsset: "avatar_sara", activityName: "30 Min Reading", approvalsReceived: 0, approvalsRequired: 2),
    PendingSubmission(memberName: "Jordan", memberAvatarAsset: "avatar_jordan", activityName: "Meditation", approvalsReceived: 1, approvalsRequired: 2),
]

// MARK: - Submission Card

private struct SubmissionCard: View {
    let submission: PendingSubmission
    let onSwipe: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    private var approveOpacity: Double {
        max(0, min(1, Double(offset.width) / 80))
    }

    private var rejectOpacity: Double {
        max(0, min(1, Double(-offset.width) / 80))
    }

    private var rotation: Double {
        Double(offset.width / 300) * 25
    }

    var body: some View {
        VStack(spacing: 0) {
            // Photo placeholder area
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.94))
                    .frame(height: 260)

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(white: 0.70))
            }
            .overlay(alignment: .topLeading) {
                // APPROVE label
                Text("APPROVE")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.green, in: Capsule())
                    .rotationEffect(.degrees(-15))
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    .opacity(approveOpacity)
            }
            .overlay(alignment: .topTrailing) {
                // REJECT label
                Text("REJECT")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.red, in: Capsule())
                    .rotationEffect(.degrees(15))
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                    .opacity(rejectOpacity)
            }

            // Info row
            HStack(spacing: 12) {
                Image(submission.memberAvatarAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(submission.memberName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(submission.activityName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                }

                Spacer()

                Text("\(submission.approvalsReceived)/\(submission.approvalsRequired) approvals")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.55))
            }
            .padding(.top, 14)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    flyOff(approved: false)
                } label: {
                    Label("Reject", systemImage: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    flyOff(approved: true)
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 16)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .offset(x: offset.width, y: offset.height * 0.3)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    isDragging = true
                    offset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    if abs(value.translation.width) > 120 {
                        flyOff(approved: value.translation.width > 0)
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            offset = .zero
                        }
                    }
                }
        )
        .animation(isDragging ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: offset)
    }

    private func flyOff(approved: Bool) {
        let targetX: CGFloat = approved ? 600 : -600
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: targetX, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(approved)
        }
    }
}

// MARK: - Swipeable Card Stack

private struct SwipeableCardStack: View {
    @State private var submissions: [PendingSubmission]

    init(submissions: [PendingSubmission]) {
        _submissions = State(initialValue: submissions)
    }

    var body: some View {
        if submissions.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(white: 0.80))
                    Text("All caught up!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                }
                .padding(.vertical, 60)
                Spacer()
            }
        } else {
            let visible = Array(submissions.prefix(3))
            ZStack {
                ForEach(Array(visible.enumerated().reversed()), id: \.element.id) { index, submission in
                    let isTop = index == 0
                    let depth = index  // 0 = top, higher = further back
                    let scale = 1.0 - (Double(depth) * 0.03)
                    let yOffset = Double(depth) * 10

                    SubmissionCard(
                        submission: submission,
                        onSwipe: { approved in
                            withAnimation(.spring()) {
                                submissions.removeAll { $0.id == submission.id }
                            }
                        }
                    )
                    .scaleEffect(isTop ? 1.0 : scale)
                    .offset(y: isTop ? 0 : yOffset)
                    .zIndex(Double(visible.count - depth))
                }
            }
        }
    }
}

// MARK: - Pending Approvals Section

private struct PendingApprovalsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pending Approvals")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            SwipeableCardStack(submissions: mockSubmissions)
        }
    }
}

// MARK: - Team View

struct TeamView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TeamShieldHeader()
                    .padding(.horizontal, 20)
                    .padding(.top, 100)

                PendingApprovalsSection()
                    .padding(.top, 32)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Team Shield Header

private struct TeamShieldHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Shield icon + title
            HStack(spacing: 8) {
                Image("GreenShard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)

                Text("Money Team")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
            }

            // Team name
            Text("Morning Forge Alliance")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.50))

            // Tier + streak
            HStack(spacing: 6) {
                Text("Emerald Tier")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.75, blue: 0.45))

                Text("•")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.65))

                Text("12 day streak")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.50))
            }
        }
    }
}

#Preview {
    TeamView()
}
