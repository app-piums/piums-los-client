//
//  PiumsClienteApp.swift
//  PiumsCliente
//
//  Created by piums on 9/04/26.
//

import SwiftUI
import GoogleSignIn

@main
struct PiumsClienteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appearance = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.preference.swiftUIScheme)
                .environment(\.locationStore, LocationStore.shared)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    print("🎨 PiumsClienteApp: onAppear - current preference: \(appearance.preference.rawValue)")
                    // Solicitar ubicación al arrancar para que esté lista cuanto antes
                    LocationStore.shared.requestIfNeeded()
                }
                .onChange(of: appearance.preference) {
                    print("🎨 PiumsClienteApp: preference changed to \(appearance.preference.rawValue)")
                    let schemeStr = appearance.preference.swiftUIScheme == .light ? "light" :
                                   appearance.preference.swiftUIScheme == .dark ? "dark" : "nil (system)"
                    print("🎨 PiumsClienteApp: applying scheme: \(schemeStr)")
                }
        }
    }
}
