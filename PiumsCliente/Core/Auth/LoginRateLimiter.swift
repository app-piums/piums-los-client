// LoginRateLimiter.swift — Protección cliente contra fuerza bruta
import Foundation

/// Limita intentos de login y forgot-password por email.
/// Progresión: 3 intentos → bloqueo 30s · 5 intentos → 5 min · 10+ → 15 min.
/// El estado vive en memoria (se resetea al reiniciar la app, intencional para UX).
final class LoginRateLimiter {
    static let shared = LoginRateLimiter()
    private init() {}

    private struct Record {
        var attempts: [Date] = []
        var lockedUntil: Date?
    }

    private var records: [String: Record] = [:]
    private let lock = NSLock()

    // MARK: - Public API

    /// Devuelve `nil` si puede intentar, o un mensaje localizado si está bloqueado.
    func shouldBlock(email: String) -> String? {
        lock.withLock {
            let key = email.lowercased()
            guard var rec = records[key] else { return nil }

            // Verificar lockout activo
            if let until = rec.lockedUntil, until > Date() {
                let remaining = Int(until.timeIntervalSinceNow.rounded(.up))
                return "Demasiados intentos. Espera \(remaining) segundos antes de continuar."
            }

            // Limpiar lockout expirado y limpiar intentos viejos (ventana 15 min)
            rec.lockedUntil = nil
            rec.attempts = rec.attempts.filter { Date().timeIntervalSince($0) < 900 }
            records[key] = rec

            return lockoutMessage(for: rec.attempts.count)
        }
    }

    /// Registra un intento fallido y aplica lockout si corresponde.
    func recordFailure(email: String) {
        lock.withLock {
            let key = email.lowercased()
            var rec = records[key] ?? Record()
            rec.attempts.append(Date())

            switch rec.attempts.count {
            case 5..<10: rec.lockedUntil = Date().addingTimeInterval(300)   // 5 min
            case 10...:  rec.lockedUntil = Date().addingTimeInterval(900)   // 15 min
            case 3...:   rec.lockedUntil = Date().addingTimeInterval(30)    // 30 s
            default:     break
            }

            records[key] = rec
        }
    }

    /// Limpia el registro tras un login exitoso.
    func reset(email: String) {
        lock.withLock { records[email.lowercased()] = nil }
    }

    // MARK: - Private

    private func lockoutMessage(for count: Int) -> String? {
        switch count {
        case ..<3:   return nil
        case 3..<5:  return "Demasiados intentos. Espera 30 segundos antes de volver a intentarlo."
        case 5..<10: return "Cuenta temporalmente bloqueada por intentos fallidos. Espera 5 minutos."
        default:     return "Demasiados intentos fallidos. Espera 15 minutos o usa ¿Olvidaste tu contraseña?"
        }
    }
}
