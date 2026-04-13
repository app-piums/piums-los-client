// Color+Piums.swift
import SwiftUI
import Combine

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
@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    private let key = "piums.colorScheme"
    private var cancellable: AnyCancellable?
    
    /// Preferencia observable para que SwiftUI re-renderice
    @Published var preference: ColorSchemePreference = .system
    
    private init() {
        // Cargar valor guardado
        let raw = UserDefaults.standard.string(forKey: key) ?? ColorSchemePreference.system.rawValue
        preference = ColorSchemePreference(rawValue: raw) ?? .system
        print("🎨 AppearanceManager: initialized with \(preference.rawValue)")
        
        // Observar cambios DESPUÉS del init y guardar en UserDefaults
        cancellable = $preference
            .dropFirst() // Ignora el valor inicial
            .sink { [weak self] newValue in
                guard let self = self else { return }
                UserDefaults.standard.set(newValue.rawValue, forKey: self.key)
                print("🎨🎨🎨 AppearanceManager: preference changed to \(newValue.rawValue), saved to UserDefaults")
                // Forzar notificación explícita a observers
                Task { @MainActor in
                    self.objectWillChange.send()
                }
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
