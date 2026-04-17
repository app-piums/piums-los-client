//
//  ThemeManager.swift
//  PiumsCliente
//

import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var storedScheme: String {
        didSet {
            UserDefaults.standard.set(storedScheme, forKey: "piums_color_scheme")
            // Se aplica inmediatamente a todas las ventanas UIKit
            DispatchQueue.main.async { self.applyToWindows() }
        }
    }

    private init() {
        self.storedScheme = UserDefaults.standard.string(forKey: "piums_color_scheme") ?? "light"
    }

    /// Devuelve el ColorScheme para SwiftUI (.preferredColorScheme)
    var colorScheme: ColorScheme? {
        switch storedScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    /// Aplica el estilo a TODAS las ventanas UIKit (incluyendo sheets, teclado, status bar)
    func applyToWindows() {
        let style: UIUserInterfaceStyle
        switch storedScheme {
        case "light": style = .light
        case "dark":  style = .dark
        default:      style = .unspecified
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for window in ws.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
