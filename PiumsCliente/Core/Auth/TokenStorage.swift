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
