// AppDelegate.swift
import UIKit
import UserNotifications
import GoogleSignIn
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase debe configurarse primero — antes de cualquier otro SDK
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        requestPushPermission(application)

        // Google Sign-In — CLIENT_ID del GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }

        return true
    }

    // MARK: - Push permission

    private func requestPushPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Token registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            try? await APIClient.request(
                .registerPushToken(token: token, platform: "ios")
            ) as VoidResponse
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Failed to register: \(error.localizedDescription)")
    }

    // MARK: - Foreground notifications (mostrar banner aunque la app esté abierta)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handlePushUserInfo(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Deep link desde notificación

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handlePushUserInfo(userInfo)

        // Navegar a reserva si viene bookingId
        if let bookingId = userInfo["bookingId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToBooking,
                object: nil,
                userInfo: ["bookingId": bookingId]
            )
        }
        completionHandler()
    }

    private func handlePushUserInfo(_ userInfo: [AnyHashable: Any]) {
        if let badge = userInfo["badge"] as? Int {
            UIApplication.shared.applicationIconBadgeNumber = badge
        }
        if let type = userInfo["type"] as? String, type == "NEW_MESSAGE" {
            NotificationCenter.default.post(name: .chatUnreadNeedsRefresh, object: nil)
        }
        if userInfo["conversationId"] != nil {
            NotificationCenter.default.post(name: .chatUnreadNeedsRefresh, object: nil)
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let navigateToBooking = Notification.Name("navigateToBooking")
}
