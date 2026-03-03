//
//  AppDelegate.swift
//  Pact
//

import UIKit
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification arrives while the app is in the foreground.
    /// We suppress the system banner and route it to our own in-app UI.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        post(notification.request.content.userInfo, foreground: true)
        completion([]) // suppress system banner
    }

    /// Called when the user taps a notification from the background or lock screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completion: @escaping () -> Void
    ) {
        post(response.notification.request.content.userInfo, foreground: false)
        completion()
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NotificationCenter.default.post(
            name: .fcmTokenRefreshed,
            object: nil,
            userInfo: ["token": token]
        )
    }

    // MARK: - Private

    private func post(_ userInfo: [AnyHashable: Any], foreground: Bool) {
        // FCM delivers data keys at top level; some configs nest under "data"
        var data: [String: String] = [:]
        for (k, v) in userInfo {
            if let key = k as? String, let val = v as? String {
                data[key] = val
            }
        }
        if let nested = userInfo["data"] as? [String: String] {
            data.merge(nested) { _, new in new }
        }
        data["_foreground"] = foreground ? "1" : "0"

        // Extract title/body from aps.alert if not already in data
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: String] {
            if data["title"] == nil { data["title"] = alert["title"] }
            if data["body"]  == nil { data["body"]  = alert["body"] }
        }

        NotificationCenter.default.post(
            name: .pactNotification,
            object: nil,
            userInfo: data
        )
    }
}
