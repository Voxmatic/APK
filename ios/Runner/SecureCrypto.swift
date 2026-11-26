import Foundation
import Security
import CryptoKit

/// Keychain-backed AES-256-GCM envelope for iOS. Mirrors the Android
/// `SecureCrypto` contract in docs/INTERNAL_APIS.md.
///
/// STATUS: IN_PROGRESS — source prepared only; not compiled or verified on macOS.
enum SecureCryptoError: Error {
  case keyCreationFailed(OSStatus)
  case invalidPayload
  case invalidCiphertext
}

final class SecureCrypto {
  private let service = "com.aitrainer.gymtrainer.ai_gym_trainer.key"
  private let account = "ai_gym_trainer_data_key"

  func encrypt(_ plaintext: String) throws -> [String: Any] {
    let key = try SymmetricKey(data: ensureKey())
    let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key)
    guard let combined = sealed.combined else { throw SecureCryptoError.invalidCiphertext }
    return [
      "schema_version": 1,
      "alg": "AES-256-GCM",
      "iv": Data(sealed.nonce).base64EncodedString(),
      "ct": combined.base64EncodedString(),
    ]
  }

  func decrypt(_ payload: [String: Any]) throws -> String {
    guard let ctB64 = payload["ct"] as? String,
          let combined = Data(base64Encoded: ctB64) else {
      throw SecureCryptoError.invalidPayload
    }
    let key = try SymmetricKey(data: ensureKey())
    let box = try AES.GCM.SealedBox(combined: combined)
    let plaintext = try AES.GCM.open(box, using: key)
    return String(decoding: plaintext, as: UTF8.self)
  }

  private func ensureKey() throws -> Data {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data {
      return data
    }
    var key = [UInt8](repeating: 0, count: 32)
    let randomStatus = SecRandomCopyBytes(kSecRandomDefault, key.count, &key)
    guard randomStatus == kSecSuccess else {
      throw SecureCryptoError.keyCreationFailed(randomStatus)
    }
    let add: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: Data(key),
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    let addStatus = SecItemAdd(add as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw SecureCryptoError.keyCreationFailed(addStatus)
    }
    return Data(key)
  }
}
