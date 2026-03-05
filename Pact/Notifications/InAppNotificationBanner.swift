//
//  InAppNotificationBanner.swift
//  Pact
//

import SwiftUI

struct InAppNotificationBanner: View {
    let payload: NotificationRouter.BannerPayload
    let onTap: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var firestoreService: FirestoreService
    @State private var isVisible = false

    private var member: TeamMember? {
        guard let uid = payload.submitterUid else { return nil }
        return firestoreService.members.first { $0.id == uid }
    }

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Avatar
                avatarView

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                    Text(payload.body)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.45))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)

            Spacer()
        }
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -140)
        .onTapGesture {
            dismiss()
            onTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isVisible = true
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 40
        switch payload.iconType {
        case .sfSymbol(let name, let color):
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                )
        case .avatar:
            if let assetName = member?.avatarAssetName, !assetName.isEmpty {
                Text(assetName)
                    .font(.system(size: 22))
                    .frame(width: size, height: size)
                    .background(Color(white: 0.92))
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(white: 0.88))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(white: 0.55))
                    )
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDismiss()
        }
    }
}
