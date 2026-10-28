import Foundation
import Security

/// Tokens JWT de la sesión, guardados en el Keychain y disponibles solo en este dispositivo.
final class TokenStore {
    private let servicio = "com.irritec.guide.tokens"

    private(set) var access: String?
    private(set) var refresh: String?

    init() {
        access = leer("access")
        refresh = leer("refresh")
    }

    var haySesion: Bool { refresh != nil }

    func guardar(access: String, refresh: String) {
        self.access = access
        self.refresh = refresh
        escribir(access, cuenta: "access")
        escribir(refresh, cuenta: "refresh")
    }

    func borrar() {
        access = nil
        refresh = nil
        eliminar("access")
        eliminar("refresh")
    }

    private func consulta(_ cuenta: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
    }

    private func leer(_ cuenta: String) -> String? {
        var query = consulta(cuenta)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    private func escribir(_ valor: String, cuenta: String) {
        eliminar(cuenta)
        var query = consulta(cuenta)
        query[kSecValueData as String] = Data(valor.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private func eliminar(_ cuenta: String) {
        SecItemDelete(consulta(cuenta) as CFDictionary)
    }
}
