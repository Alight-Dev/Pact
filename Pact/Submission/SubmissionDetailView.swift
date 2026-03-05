//
//  SubmissionDetailView.swift
//  Pact
//

import SwiftUI

struct SubmissionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var showCamera = false

    private var submission: Submission? {
        firestoreService.myTodaySubmission
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if let submission {
                        // Proof photo
                        proofPhotoSection(submission: submission)

                        // Status badge + approval count
                        statusSection(submission: submission)

                        // Retry button (rejected only)
                        if submission.status == "rejected" {
                            retryButton
                        }
                    } else {
                        Text("No submission found for today.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Today's Submission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.black)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            UploadProofView()
        }
    }

    // MARK: - Proof photo

    @ViewBuilder
    private func proofPhotoSection(submission: Submission) -> some View {
        Group {
            if let urlString = submission.photoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.94))
                            .frame(height: 280)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    case .failure:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.94))
                            .frame(height: 280)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color(white: 0.70))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.94))
                    .frame(height: 280)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(white: 0.70))
                    )
            }
        }
    }

    // MARK: - Status section

    @ViewBuilder
    private func statusSection(submission: Submission) -> some View {
        VStack(spacing: 16) {
            // Status pill
            HStack(spacing: 8) {
                Image(systemName: statusIcon(for: submission.status))
                    .font(.system(size: 15, weight: .semibold))
                Text(statusLabel(for: submission.status))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(statusForeground(for: submission.status))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(statusBackground(for: submission.status))
            )

            // Approval count (only meaningful when pending)
            if submission.status == "pending" {
                let required = max(1, submission.approvalsRequired)
                Text("\(submission.approvalsReceived) of \(required) teammates approved")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.50))
            }

            // Activity name
            Text(submission.activityName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.40))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.97))
        )
    }

    // MARK: - Retry button

    private var retryButton: some View {
        Button {
            showCamera = true
        } label: {
            Text("Replace Photo")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func statusIcon(for status: String) -> String {
        switch status {
        case "approved", "auto_approved": return "checkmark.circle.fill"
        case "rejected":                  return "xmark.circle.fill"
        default:                          return "clock.fill"
        }
    }

    private func statusLabel(for status: String) -> String {
        switch status {
        case "approved", "auto_approved": return "Approved — Unlocked!"
        case "rejected":                  return "Rejected — tap + to retry"
        default:                          return "Waiting for votes"
        }
    }

    private func statusForeground(for status: String) -> Color {
        switch status {
        case "approved", "auto_approved": return Color(red: 0.10, green: 0.50, blue: 0.10)
        case "rejected":                  return Color(red: 0.75, green: 0.15, blue: 0.10)
        default:                          return Color(red: 0.50, green: 0.38, blue: 0.00)
        }
    }

    private func statusBackground(for status: String) -> Color {
        switch status {
        case "approved", "auto_approved": return Color(red: 0.88, green: 0.97, blue: 0.88)
        case "rejected":                  return Color(red: 0.98, green: 0.89, blue: 0.88)
        default:                          return Color(red: 0.98, green: 0.96, blue: 0.86)
        }
    }
}

#Preview {
    SubmissionDetailView()
        .environmentObject(FirestoreService())
}
