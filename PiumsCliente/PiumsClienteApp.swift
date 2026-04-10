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
    @State private var appearance = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.swiftUIScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    appearance.applyOnLaunch()
                }
        }
    }
}
