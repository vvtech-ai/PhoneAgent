import Foundation

/// Notification decoration is not SDK identity verification.
enum TrustedNotificationPolicy {
  static let maximumAvatarBytes = 2 * 1024 * 1024
  static let timeout: TimeInterval = 5

  static func isIncoming(_ fields: [AnyHashable: Any]) -> Bool {
    ["token", "phoneno", "targetNumber", "sequence"].allSatisfy {
      guard let value = fields[$0] else { return false }
      return !text(value).isEmpty
    }
  }

  static func text(_ raw: Any) -> String {
    let value: String
    if let string = raw as? String { value = string }
    else if let number = raw as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID() { value = number.stringValue }
    else { return "" }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.rangeOfCharacter(from: .controlCharacters) == nil else { return "" }
    return trimmed
  }

  static func avatarURL(_ value: Any?) -> URL? {
    guard let value, let url = URL(string: text(value)),
          url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
          url.user == nil, url.password == nil else { return nil }
    return url
  }

  static func acceptsBytes(received: Int, additional: Int) -> Bool {
    received >= 0 && additional >= 0 && received <= maximumAvatarBytes &&
      additional <= maximumAvatarBytes - received
  }
}
