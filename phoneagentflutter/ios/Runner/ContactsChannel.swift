import Contacts
import Flutter

/// Thin system adapter. Directory notes and phone policies remain in Dart.
final class ContactsChannel: NSObject, FlutterPlugin {
  private let store = CNContactStore()
  private let worker = DispatchQueue(label: "com.vvtech.phoneagent.contacts", qos: .userInitiated)
  private var busy = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.vvtech.phone_agent/contacts", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ContactsChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "authorization" { result(authorization()); return }
    guard call.method == "load" || call.method == "requestAuthorization" else {
      result(FlutterMethodNotImplemented); return
    }
    let permissionOnly = call.method == "requestAuthorization"
    guard !busy else {
      result(FlutterError(code: "busy", message: "Contacts request already active", details: nil))
      return
    }
    busy = true
    let request = permissionOnly || ((call.arguments as? [String: Any])?["requestPermission"] as? Bool ?? false)
    if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined && request {
      store.requestAccess(for: .contacts) { [weak self] _, error in
        DispatchQueue.main.async {
          guard let self = self else { return }
          if error != nil && CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            self.finish(FlutterError(code: "permission_failed", message: "Contacts permission request failed", details: nil), result)
          } else {
            if permissionOnly { self.finish(self.authorization(), result) } else { self.read(result) }
          }
        }
      }
    } else {
      if permissionOnly { finish(authorization(), result) } else { read(result) }
    }
  }

  private func authorization() -> [String: Any] {
    let state = access()
    return ["access": state, "canRequest": state == "notDetermined"]
  }

  private func access() -> String {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    // CNAuthorizationStatusLimited has value 4 on iOS 18+. A raw-value check
    // keeps the existing Xcode 15.2 toolchain buildable without an SDK upgrade.
    if #available(iOS 18.0, *), status.rawValue == 4 { return "limited" }
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unsupported"
    }
  }

  private func read(_ result: @escaping FlutterResult) {
    let permission = access()
    guard permission == "authorized" || permission == "limited" else {
      finish(["access": permission], result)
      return
    }
    worker.async { [weak self] in
      guard let self = self else { return }
      do {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey,
                    CNContactOrganizationNameKey, CNContactPhoneNumbersKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true
        request.sortOrder = .userDefault
        var rows = [[String: String]]()
        try self.store.enumerateContacts(with: request) { contact, _ in
          let fullName = contact.familyName + contact.givenName
          let name = !fullName.isEmpty ? fullName : !contact.nickname.isEmpty
            ? contact.nickname : contact.organizationName
          // Do not adopt the old iOS UI's first-number-only behavior.
          for number in contact.phoneNumbers {
            let label = number.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? ""
            rows.append(["name": name, "phone": number.value.stringValue, "label": label, "contactId": contact.identifier])
          }
        }
        DispatchQueue.main.async {
          let current = self.access()
          if current == permission {
            self.finish(["access": current, "rows": rows], result)
          } else if current == "authorized" || current == "limited" {
            // Authorization scope changed during enumeration: reread its subset.
            self.read(result)
          } else {
            self.finish(["access": current], result)
          }
        }
      } catch {
        DispatchQueue.main.async {
          let current = self.access()
          if current == "denied" || current == "restricted" {
            self.finish(["access": current], result)
          } else {
            self.finish(FlutterError(code: "read_failed", message: "Contacts could not be read", details: nil), result)
          }
        }
      }
    }
  }

  private func finish(_ value: Any, _ result: FlutterResult) {
    busy = false
    result(value)
  }
}
