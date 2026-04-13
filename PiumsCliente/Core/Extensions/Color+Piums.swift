// Color+Piums.swift
import SwiftUI
import Combine

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

final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    private let key = "piums.colorScheme"

    @Published var preference: ColorSchemePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: key)
            applyToWindows(preference)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? ColorSchemePreference.system.rawValue
        preference = ColorSchemePreference(rawValue: raw) ?? .system
    }

    func applyOnLaunch() {
        applyToWindows(preference)
    }

    private func applyToWindows(_ pref: ColorSchemePreference) {
        let style: UIUserInterfaceStyle
        switch pref {
        case .light:  style = .light
        case .dark:   style = .dark
        case .system: style = .unspecified
        }
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                    ?? UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene }).first else { return }
            scene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
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

    var swiftUIScheme: ColorScheme? {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}
