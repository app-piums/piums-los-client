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
    @AppStorage("piums.colorScheme") private var colorSchemeRaw: String = ColorSchemePreference.system.rawValue

    private var colorScheme: ColorScheme? {
        ColorSchemePreference(rawValue: colorSchemeRaw)?.swiftUIScheme
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(colorScheme)
                .environmentObject(AppearanceManager.shared)
                .environment(\.locationStore, LocationStore.shared)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    print("🎨 PiumsClienteApp: onAppear - current preference: \(colorSchemeRaw)")
                    LocationStore.shared.requestIfNeeded()
                }
        }
    }
}
