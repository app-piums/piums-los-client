//
//  PiumsClienteApp.swift
//  PiumsCliente
//
//  Created by piums on 9/04/26.
//

import SwiftUI
import GoogleSignIn

// Detecta claves de pago sin reemplazar antes de que el build llegue a QA/Prod.
// Solo valida STRIPE_PUBLISHABLE_KEY porque es la única sin fallback seguro:
// un placeholder aquí haría que los pagos fallen silenciosamente en producción.
private func validateBuildConfig() {
    let placeholders = ["REPLACE_ME", "YOUR_KEY", "INSERT_KEY"]
    guard let stripeKey = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String else {
        return // no inyectada en este build — se aceptará el fallo de Stripe en runtime
    }
    let isPlaceholder = placeholders.contains { stripeKey.contains($0) }
    assert(!isPlaceholder,
           "⚠️ STRIPE_PUBLISHABLE_KEY todavía es un placeholder ('\(stripeKey)'). Actualiza Release.xcconfig antes de distribuir.")
}

@main
struct PiumsClienteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        validateBuildConfig()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(themeManager.colorScheme)
                .environmentObject(themeManager)
                .environment(\.locationStore, LocationStore.shared)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    themeManager.applyToWindows()
                    LocationStore.shared.requestIfNeeded()
                }
                .onChange(of: themeManager.storedScheme) { _, _ in
                    themeManager.applyToWindows()
                }
        }
    }
}
