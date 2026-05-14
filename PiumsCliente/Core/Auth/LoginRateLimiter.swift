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

            if let until = rec.lockedUntil, until > Date() {
                let remaining = Int(until.timeIntervalSinceNow.rounded(.up))
                return LoginRateLimiter.countdownMessage(seconds: remaining)
            }

            rec.lockedUntil = nil
            rec.attempts = rec.attempts.filter { Date().timeIntervalSince($0) < 900 }
            records[key] = rec

            return lockoutMessage(for: rec.attempts.count)
        }
    }

    /// Fecha exacta en que expira el bloqueo, para mostrar countdown en vivo.
    func lockedUntil(email: String) -> Date? {
        lock.withLock {
            let key = email.lowercased()
            guard let until = records[key]?.lockedUntil, until > Date() else { return nil }
            return until
        }
    }

    static func countdownMessage(seconds: Int) -> String {
        if seconds >= 3600 {
            return "Demasiados intentos. Vuelve a intentarlo en \(seconds / 3600)h."
        } else if seconds >= 60 {
            let mins = (seconds + 59) / 60
            return "Demasiados intentos. Vuelve a intentarlo en \(mins) min."
        }
        return "Demasiados intentos. Intenta de nuevo en \(seconds)s ⏱"
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
        case 3..<5:  return "Contraseña incorrecta. Te quedan \(5 - count) intento(s) antes del bloqueo."
        case 5..<10: return "Cuenta bloqueada temporalmente. Espera 5 minutos e inténtalo de nuevo."
        default:     return "Demasiados intentos fallidos. Espera 15 minutos o recupera tu contraseña."
        }
    }
}
