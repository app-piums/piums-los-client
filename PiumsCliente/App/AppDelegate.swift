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

        // Google Sign-In — CLIENT_ID del GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }

        return true
    }

    // MARK: - Push permission (llamar después de que el usuario inicia sesión)

    static func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
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

    // MARK: - Deep link desde notificación (tap del usuario)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handlePushUserInfo(userInfo)

        // Backend envía "chatId"; cuando cambies la clave a "conversationId" ambas funcionan
        let type = (userInfo["type"] as? String ?? "").uppercased()
        let conversationId = (userInfo["conversationId"] as? String)
                          ?? (userInfo["chatId"] as? String)

        if let conversationId {
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        } else if type == "COUPON_SENT" || type == "COUPON_EXPIRING" || type == "DISCOUNT" {
            NotificationCenter.default.post(name: .navigateToCoupons, object: nil)
        } else if (type == "DISPUTE_OPENED" || type == "DISPUTE_RESOLVED" || type == "DISPUTE_MESSAGE"),
                  let disputeId = userInfo["disputeId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToDispute,
                object: nil,
                userInfo: ["disputeId": disputeId]
            )
        } else if type == "PAYMENT_CAPTURE_FAILED", let bookingId = userInfo["bookingId"] as? String {
            // El hold de la tarjeta venció y la captura automática falló. Navegar al detalle
            // de la reserva donde el usuario puede iniciar el pago manualmente.
            NotificationCenter.default.post(
                name: .navigateToBooking,
                object: nil,
                userInfo: ["bookingId": bookingId, "requiresPayment": true]
            )
        } else if let bookingId = userInfo["bookingId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToBooking,
                object: nil,
                userInfo: ["bookingId": bookingId]
            )
        } else if let disputeId = userInfo["disputeId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToDispute,
                object: nil,
                userInfo: ["disputeId": disputeId]
            )
        }
        completionHandler()
    }

    // MARK: - Silent push / background fetch
    // Llamado cuando el backend envía content-available:1 con la app en background.
    // Permite sincronizar contadores sin que el usuario abra la app.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        handlePushUserInfo(userInfo)
        Task {
            await ChatRealtimeStore.shared.refreshUnread()
            await NotificationsStore.shared.refresh()
            completionHandler(.newData)
        }
    }

    private func handlePushUserInfo(_ userInfo: [AnyHashable: Any]) {
        if let badge = userInfo["badge"] as? Int {
            UNUserNotificationCenter.current().setBadgeCount(badge)
        }
        let type = userInfo["type"] as? String ?? ""
        if type == "NEW_MESSAGE" || userInfo["conversationId"] != nil || userInfo["chatId"] != nil {
            NotificationCenter.default.post(name: .chatUnreadNeedsRefresh, object: nil)
        } else {
            // Notificación no-chat (booking, pago, etc.) → refrescar campana
            NotificationCenter.default.post(name: .notificationsNeedRefresh, object: nil)
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let navigateToBooking        = Notification.Name("navigateToBooking")
    static let navigateToMySpace        = Notification.Name("navigateToMySpace")
    static let navigateToProfile        = Notification.Name("navigateToProfile")
    static let navigateToConversation   = Notification.Name("navigateToConversation")
    static let navigateToCoupons        = Notification.Name("navigateToCoupons")
    static let navigateToDispute        = Notification.Name("navigateToDispute")
    static let notificationsNeedRefresh = Notification.Name("notifications.needs.refresh")
}
