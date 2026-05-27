// TokenStorage.swift — almacena tokens en Keychain, nunca en UserDefaults
import Foundation
import Security

final class TokenStorage {
    static let shared = TokenStorage()
    private init() {}

    private let accessKey  = "piums.access_token"
    private let refreshKey = "piums.refresh_token"

    var accessToken: String? {
        get { read(key: accessKey) }
        set { newValue == nil ? delete(key: accessKey) : save(key: accessKey, value: newValue!) }
    }

    var refreshToken: String? {
        get { read(key: refreshKey) }
        set { newValue == nil ? delete(key: refreshKey) : save(key: refreshKey, value: newValue!) }
    }

    func clearAll() {
        delete(key: accessKey)
        delete(key: refreshKey)
    }

    // MARK: - JWT utilities

    /// `true` si el access token ya expiró o no existe (basado en el claim `exp`).
    var isAccessTokenExpired: Bool {
        guard let token = accessToken else { return true }
        guard let expiry = jwtExpiry(of: token) else { return false } // no parseable → asumir válido
        return expiry <= Date().addingTimeInterval(30) // 30s de margen
    }

    /// Fecha de expiración del access token, o `nil` si no se puede decodificar.
    var accessTokenExpiry: Date? {
        guard let token = accessToken else { return nil }
        return jwtExpiry(of: token)
    }

    /// Valida que un string tenga estructura de JWT (3 partes base64url separadas por punto).
    static func looksLikeJWT(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "=" }
        }
    }

    // MARK: - Private JWT decoding

    private func jwtExpiry(of token: String) -> Date? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }

        guard let data    = Data(base64Encoded: b64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp     = payload["exp"] as? TimeInterval else { return nil }

        return Date(timeIntervalSince1970: exp)
    }

    // MARK: - Private helpers

    private func save(key: String, value: String) {
        let data = Data(value.utf8)
        // kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly:
        //   - Requiere que el dispositivo tenga código de acceso configurado
        //   - El ítem se elimina si se quita el código (previene extracción sin auth)
        //   - No pide biometría en cada acceso (UX razonable)
        //   - Nunca migra a iCloud ni a otro dispositivo
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrAccount:    key,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Fallback si el dispositivo no tiene código configurado (desarrollo/simulador)
            let fallback: [CFString: Any] = [
                kSecClass:          kSecClassGenericPassword,
                kSecAttrAccount:    key,
                kSecValueData:      data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            SecItemDelete(fallback as CFDictionary)
            SecItemAdd(fallback as CFDictionary, nil)
        }
    }

    private func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}
