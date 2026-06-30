import Foundation
import Security

/// Thin Keychain wrapper for storing provider API keys.
///
/// We use the legacy `SecItem` API (not the macOS 13+ `Keychain` Swift API)
/// so the project compiles back to macOS 13. Keys are stored as generic
/// password items with a fixed service prefix and account = provider name.
public enum KeychainStore {
    private static let service = "com.igormartynyuk.NotchMind.apikey"

    public static func setAPIKey(_ key: String, for provider: LLMProvider) throws {
        let account = provider.rawValue
        let data = Data(key.utf8)

        // Delete any existing item first so upserts don't return errSecDuplicateItem.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard !key.isEmpty else { return }  // empty key = "clear"

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledOSStatus(status)
        }
    }

    public static func getAPIKey(for provider: LLMProvider) -> String? {
        let account = provider.rawValue
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func deleteAPIKey(for provider: LLMProvider) {
        let account = provider.rawValue
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    public enum KeychainError: Error, Sendable {
        case unhandledOSStatus(OSStatus)
    }
}
