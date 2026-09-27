import Foundation
import Security

/// Безопасное хранилище секретов в Apple Keychain (AES-256 + аппаратная защита Secure Enclave)
struct KeychainHelper {
    static let service = "dev.hypernotch.app.secrets"
    static let legacyService = "dev.vibenotch.app.secrets"
    
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        // Remove existing item if any
        SecItemDelete(query as CFDictionary)
        
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return true
        }
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load(key: String) -> String? {
        if let val = loadFrom(serviceName: service, key: key) {
            return val
        }
        // Fallback and migrate from legacy service
        if let legacyVal = loadFrom(serviceName: legacyService, key: key) {
            _ = save(key: key, value: legacyVal)
            return legacyVal
        }
        return nil
    }
    
    private static func loadFrom(serviceName: String, key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(legacyQuery as CFDictionary)
    }
}
