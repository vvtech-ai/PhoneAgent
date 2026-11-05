import Foundation

/// Pure retry admission. Native requests can fail in background; never loop there.
struct TrustedIdentityActivityAdmission {
  private var eventId: String?
  private var foregroundAttempts = 0
  private var backgroundAttempted = false

  mutating func admit(event: String, foreground: Bool) -> Bool {
    if eventId != event {
      eventId = event; foregroundAttempts = 0; backgroundAttempted = false
    }
    if foreground {
      guard foregroundAttempts < 2 else { return false }
      foregroundAttempts += 1
      return true
    }
    guard !backgroundAttempted else { return false }
    backgroundAttempted = true
    return true
  }

  mutating func reset() {
    eventId = nil; foregroundAttempts = 0; backgroundAttempted = false
  }
}
