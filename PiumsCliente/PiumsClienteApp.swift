//
//  PiumsClienteApp.swift
//  PiumsCliente
//
//  Created by piums on 9/04/26.
//

import SwiftUI

@main
struct PiumsClienteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
