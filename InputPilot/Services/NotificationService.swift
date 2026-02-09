import Foundation
import UserNotifications

final class NotificationService: NotificationServicing {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestNotificationPermissionIfNeeded() async -> UNAuthorizationStatus {
        let currentStatus = await notificationAuthorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        _ = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in
                continuation.resume(returning: ())
            }
        }

        return await notificationAuthorizationStatus()
    }

    func sendNotification(title: String, body: String) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }
}

final class NoOpNotificationService: NotificationServicing {
    func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        .denied
    }

    func requestNotificationPermissionIfNeeded() async -> UNAuthorizationStatus {
        .denied
    }

    func sendNotification(title: String, body: String) async -> Bool {
        _ = title
        _ = body
        return false
    }
}
