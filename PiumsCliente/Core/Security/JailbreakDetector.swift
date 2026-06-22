import Foundation

/// Detección de indicadores básicos de jailbreak.
/// Puede ser evadida en dispositivos con jailbreak avanzado, pero captura la mayoría de casos.
enum JailbreakDetector {

    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return hasJailbreakFiles || canWriteOutsideSandbox
        #endif
    }

    private static var hasJailbreakFiles: Bool {
        let suspects = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/usr/bin/ssh",
            "/private/var/stash",
            "/var/checkra1n.dmg",
            "/var/mobile/Library/Application Support/Dopamine",
            "/usr/lib/libhooker.dylib",
        ]
        return suspects.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static var canWriteOutsideSandbox: Bool {
        let path = "/private/piums_rwtest_\(Int.random(in: 1_000_000...9_999_999))"
        do {
            try "x".write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: path)
            return true
        } catch { return false }
    }
}
