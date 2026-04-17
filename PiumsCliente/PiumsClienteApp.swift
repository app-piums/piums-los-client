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
    @StateObject private var themeManager = ThemeManager.shared

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
