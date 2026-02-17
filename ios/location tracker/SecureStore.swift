import Foundation
import Security

enum SecureStoreKey: String {
    case uid = "secure_uid"
    case homeLatitude = "secure_home_latitude"
    case homeLongitude = "secure_home_longitude"
}

enum SecureStore {
    @discardableResult
    static func setString(_ value: String, for key: SecureStoreKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return setData(data, for: key)
    }

    static func getString(for key: SecureStoreKey) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func setDouble(_ value: Double, for key: SecureStoreKey) -> Bool {
        return setString(String(value), for: key)
    }

    static func getDouble(for key: SecureStoreKey) -> Double? {
        guard let raw = getString(for: key) else { return nil }
        return Double(raw)
    }

    @discardableResult
    static func remove(_ key: SecureStoreKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    @discardableResult
    private static func setData(_ data: Data, for key: SecureStoreKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        var createQuery = query
        createQuery.merge(attributes) { _, new in new }
        let createStatus = SecItemAdd(createQuery as CFDictionary, nil)
        return createStatus == errSecSuccess
    }

    private static func getData(for key: SecureStoreKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
}
