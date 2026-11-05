import Foundation
import CoreFoundation

/// Safe display projection; no push token, certificate payload, or remote image.
struct TrustedIdentityActivityProjection: Equatable {
  let avatarData: Data
  let eventId: String
  let userName: String
  let title: String
  let departmentAndPosition: String
  let companyName: String
  let job: String
  let school: String
  let showType: Int
  let callerPhone: String
  let expiresAt: Date

  init?(report: [String: Any], now: Date) {
    guard let eventId = report["eventId"] as? String, UUID(uuidString: eventId) != nil,
          let fresh = report["activityFresh"] as? NSNumber,
          CFGetTypeID(fresh) == CFBooleanGetTypeID(), fresh.boolValue,
          let identity = report["identity"] as? [String: Any],
          ["verified", "uncertified"].contains(identity["verification"] as? String ?? "") else { return nil }
    func text(_ key: String) -> String {
      guard let raw = identity[key] as? String else { return "" }
      let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard value.count <= 1024, value.rangeOfCharacter(from: .controlCharacters) == nil else { return "" }
      return value
    }
    guard let rawTime = Double(text("callTime")), rawTime.isFinite, rawTime > 0 else { return nil }
    let started = Date(timeIntervalSince1970: rawTime > 1e10 ? rawTime / 1000 : rawTime)
    let age = now.timeIntervalSince(started)
    guard age >= -60, age <= 1200 else { return nil }
    let type = Int(text("showType")) ?? Int(text("identityType")) ?? 0
    if identity["verification"] as? String == "uncertified" && type != 6 { return nil }
    func first(_ keys: [String]) -> String { keys.map(text).first { !$0.isEmpty } ?? "" }
    let name = first(["name", "userName", "realName"])
    let department = first(["deptZh", "dept", "department"])
    let position = first(["position", "job", "jobTitle"])
    let company = first(["commonName", "companyName", "organizationName"])
    let displayName: String
    switch type {
    case 1: displayName = position.isEmpty ? name : position
    case 2: displayName = department.isEmpty ? name : department
    case 3, 4: displayName = company.isEmpty ? name : company
    default: displayName = name
    }
    let detail = [type == 2 ? "" : department, type == 1 ? "" : position]
      .filter { !$0.isEmpty }.joined(separator: " ")
    let fields: [String: Any] = [
      "eventId": eventId, "userName": displayName, "title": text("title"),
      "departmentAndPosition": detail, "companyName": company,
      "job": text("job"), "school": text("school"), "showType": type,
      "callerPhone": text("phoneno")
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: fields), data.count <= 3500,
          !text("phoneno").isEmpty else { return nil }
    let image = identity["avatarData"] as? Data ?? Data()
    avatarData = image.count <= 32768 ? image : Data()
    self.eventId = eventId
    userName = displayName
    title = text("title")
    departmentAndPosition = detail
    companyName = company
    job = text("job")
    school = text("school")
    showType = type
    callerPhone = text("phoneno")
    expiresAt = started.addingTimeInterval(1200)
  }
}
