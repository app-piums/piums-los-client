// Color+Piums.swift
import SwiftUI

// MARK: - Brand colors
// Xcode genera automáticamente desde Assets.xcassets:
//   Color.piumsOrange, .piumsBackground, .piumsBackgroundSecondary,
//   .piumsBackgroundElevated, .piumsLabel, .piumsLabelSecondary, .piumsSeparator
// No redeclarar aquí — solo el legacy helper y el hex init.

extension Color {
    /// Legacy — usar .piumsBackground del asset catalog en código nuevo
    static let piumsDark = Color(hex: "#1A1A1A")

    // MARK: - Hex init
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - AppearanceManager

/// Gestiona la preferencia de apariencia del usuario (light / dark / system)
@Observable
final class AppearanceManager {
    static let shared = AppearanceManager()
    private init() {}

    @ObservationIgnored
    private let key = "piums.colorScheme"

    var colorScheme: ColorSchemePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: key) ?? "system"
            return ColorSchemePreference(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            apply(newValue)
        }
    }

    var swiftUIScheme: ColorScheme? {
        switch colorScheme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    func apply(_ scheme: ColorSchemePreference) {
        let style: UIUserInterfaceStyle
        switch scheme {
        case .light:  style = .light
        case .dark:   style = .dark
        case .system: style = .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }

    func applyOnLaunch() { apply(colorScheme) }
}

enum ColorSchemePreference: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var displayName: String {
        switch self {
        case .system: return "Automático"
        case .light:  return "Claro"
        case .dark:   return "Oscuro"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon.stars"
        }
    }
}
