// LoginRateLimiter.swift — Protección cliente contra fuerza bruta
import Foundation

/// Limita intentos de login y forgot-password por email.
/// Progresión: 3 intentos → bloqueo 30s · 5 intentos → 5 min · 10+ → 15 min.
/// El bloqueo persiste en UserDefaults para sobrevivir reinicios de la app.
final class LoginRateLimiter {
    static let shared = LoginRateLimiter()
    private init() {}

    private struct Record {
        var attempts: [Date] = []
        var lockedUntil: Date?
    }

    private var records: [String: Record] = [:]
    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private func udKey(_ email: String) -> String { "rl.lock.\(email)" }

    // MARK: - Public API

    /// Devuelve `nil` si puede intentar, o un mensaje localizado si está bloqueado.
    func shouldBlock(email: String) -> String? {
        lock.withLock {
            let key = email.lowercased()
            var rec = records[key] ?? Record()

            // Restaurar bloqueo persistido si no está en memoria
            if rec.lockedUntil == nil,
               let ts = defaults.object(forKey: udKey(key)) as? Double {
                let saved = Date(timeIntervalSince1970: ts)
                if saved > Date() { rec.lockedUntil = saved }
                records[key] = rec
            }

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
            // Primero memoria, luego UserDefaults
            if let until = records[key]?.lockedUntil, until > Date() { return until }
            if let ts = defaults.object(forKey: udKey(key)) as? Double {
                let saved = Date(timeIntervalSince1970: ts)
                if saved > Date() { return saved }
            }
            return nil
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

            // Persistir fecha de desbloqueo para sobrevivir reinicios
            if let until = rec.lockedUntil {
                defaults.set(until.timeIntervalSince1970, forKey: udKey(key))
            }
        }
    }

    /// Limpia el registro tras un login exitoso.
    func reset(email: String) {
        lock.withLock {
            let key = email.lowercased()
            records[key] = nil
            defaults.removeObject(forKey: udKey(key))
        }
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
