// Color+Piums.swift
import SwiftUI

extension Color {
    // piumsOrange, piumsBackground, piumsBackgroundElevated, piumsBackgroundSecondary,
    // piumsLabel, piumsLabelSecondary y piumsSeparator son auto-generados por Xcode
    // desde los .colorset en Assets.xcassets — no definir aquí para evitar ambigüedad.

    static let piumsDark = Color(hex: "#1A1A1A")

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
