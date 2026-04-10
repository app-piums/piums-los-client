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
    @AppStorage("piums.colorScheme") private var appearanceRaw = ColorSchemePreference.system.rawValue

    private var preferredScheme: ColorScheme? {
        ColorSchemePreference(rawValue: appearanceRaw)?.swiftUIScheme
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(preferredScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    AppearanceManager.shared.applyOnLaunch()
                }
        }
    }
}
