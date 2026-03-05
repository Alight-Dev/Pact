//
//  NotificationRouter.swift
//  Pact
//

import Foundation
import Combine

// MARK: - Notification Names

extension Notification.Name {
    static let pactNotification  = Notification.Name("PactNotificationReceived")
    static let fcmTokenRefreshed = Notification.Name("FCMTokenRefreshed")
}

// MARK: - NotificationRouter

@MainActor
final class NotificationRouter: ObservableObject {

    struct BannerPayload: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let tab: AppTab
        let submitterUid: String?
        let isForeground: Bool
    }

    @Published var activeBanner: BannerPayload?
    @Published var pendingTabSwitch: AppTab?

    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default
            .publisher(for: .pactNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.handle(note)
            }
    }

    // MARK: - Private

    private func handle(_ note: Foundation.Notification) {
        guard let userInfo = note.userInfo as? [String: String] else { return }

        let type         = userInfo["type"] ?? ""
        let isForeground = userInfo["_foreground"] == "1"
        let title        = userInfo["title"] ?? titleFor(type: type)
        let body         = userInfo["body"]  ?? bodyFor(type: type, userInfo: userInfo)
        let submitterUid = userInfo["submitterUid"]
        let tab          = destinationTab(for: type)

        if isForeground {
            activeBanner = BannerPayload(
                title: title,
                body: body,
                tab: tab,
                submitterUid: submitterUid,
                isForeground: true
            )
        } else {
            pendingTabSwitch = tab
        }
    }

    private func destinationTab(for type: String) -> AppTab {
        switch type {
        case "vote_needed", "team_joined":
            return .team
        default:
            return .home
        }
    }

    private func titleFor(type: String) -> String {
        switch type {
        case "vote_needed":           return "New Submission"
        case "team_joined":           return "New Teammate!"
        case "submission_approved":   return "Proof approved! 🎉"
        case "submission_rejected":   return "Proof rejected"
        case "forge_pact_ready":      return "🛡 Pact Forged!"
        case "daily_complete":        return "Pact complete! 🔥"
        default:                      return "Pact"
        }
    }

    private func bodyFor(type: String, userInfo: [String: String]) -> String {
        switch type {
        case "vote_needed":
            let nick     = userInfo["submitterNickname"] ?? "A teammate"
            let activity = userInfo["activityName"] ?? "their proof"
            return "\(nick) submitted \(activity). Tap to vote →"
        case "team_joined":
            let nick = userInfo["joinerNickname"] ?? "Someone"
            return "\(nick) just joined your team."
        case "submission_approved":
            return "Your team voted you in. Keep the streak alive!"
        case "submission_rejected":
            return "Your team didn't approve your submission. Try again tomorrow."
        case "forge_pact_ready":
            return "All members agreed. The challenge starts today — don't break it."
        case "daily_complete":
            return "Every teammate finished today. Streak safe!"
        default:
            return ""
        }
    }
}
