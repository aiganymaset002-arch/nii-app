//
//  Keychain.swift
//  NII App
//

import Foundation
#if canImport(Security)
import Security
#endif

enum Keychain {
    private static let service = "kz.nii.app"

    #if canImport(Security)
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read(_ account: String) -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }

    static func write(_ data: Data, _ account: String) {
        delete(account)
        var q = query(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
    #else
    // Linux (tests only)
    private static var memory: [String: Data] = [:]
    static func read(_ account: String) -> Data? { memory[account] }
    static func write(_ data: Data, _ account: String) { memory[account] = data }
    static func delete(_ account: String) { memory[account] = nil }
    #endif
}
