import ActivityKit
import Foundation
import UIKit
import PhoneAgentTrustedCaller

@available(iOS 16.1, *)
@MainActor
final class TrustedIdentityActivityManager {
  static let shared = TrustedIdentityActivityManager()
  private var desired: TrustedIdentityActivityProjection?
  private var lastReport: [String: Any]?
  private var generation = 0
  private var initialized = false
  private var admission = TrustedIdentityActivityAdmission()
  private var activity: Activity<TrustedIdentityActivityAttributes>?
  private var work: Task<Void, Never>?
  private var expiration: Task<Void, Never>?
  private var dismissedEventId: String?

  private func trace(_ code: String, _ result: String) {
    TrustedCallerPlugin.recordIncomingStage("incomingActivity", code: code, result: result)
  }

  func receive(_ report: [String: Any]?) {
    lastReport = report
    let next = report.flatMap { TrustedIdentityActivityProjection(report: $0, now: Date()) }
    if initialized && next == desired {
      if next == nil || work != nil { return }
      if let activity {
        if activity.activityState == .active { return }
        if #available(iOS 16.2, *), activity.activityState == .stale { return }
        dismissedEventId = next?.eventId
        self.activity = nil
      }
      if next?.eventId == dismissedEventId { return }
    }
    let changed = desired != next
    initialized = true
    desired = next
    generation += 1
    let captured = generation
    work?.cancel()
    if changed { expiration?.cancel() }
    work = Task {
      defer { if captured == generation { work = nil } }
      // Never tear down a successful same-event Activity merely on resume.
      if changed || next == nil {
        for previous in Activity<TrustedIdentityActivityAttributes>.activities {
          await previous.end(dismissalPolicy: .immediate)
        }
        guard captured == generation, !Task.isCancelled else { return }
        activity = nil
        trace("IOS_ACTIVITY_ENDED", "cancelled")
      }
      guard captured == generation, !Task.isCancelled else { return }
      guard let next else {
        admission.reset()
        if report != nil { trace("IOS_ACTIVITY_INELIGIBLE", "received") }
        return
      }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        trace("IOS_ACTIVITY_DISABLED", "failed"); return
      }
      let foreground = UIApplication.shared.applicationState == .active
      guard admission.admit(event: next.eventId, foreground: foreground) else {
        trace(foreground ? "IOS_ACTIVITY_RETRY_EXHAUSTED" : "IOS_ACTIVITY_BACKGROUND_DEFERRED", "failed")
        return
      }
      // Match the reference's public request attempt. Background success is not guaranteed.
      var attributes = TrustedIdentityActivityAttributes(
        eventId: next.eventId, userName: next.userName, title: next.title,
        departmentAndPosition: next.departmentAndPosition, companyName: next.companyName,
        job: next.job, school: next.school, showType: next.showType, callerPhone: next.callerPhone,
        avatarData: compressedAvatar(next.avatarData)
      )
      let state = TrustedIdentityActivityAttributes.ContentState(displayStatus: 2, verificationFailMessage: "")
      func fits() -> Bool {
        guard let a = try? JSONEncoder().encode(attributes), let s = try? JSONEncoder().encode(state) else { return false }
        return a.count + s.count <= 4096
      }
      if !fits() { attributes.avatarData = Data() }
      guard fits() else { trace("IOS_ACTIVITY_SIZE_REJECTED", "failed"); return }
      do {
        let created = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
        guard captured == generation, !Task.isCancelled else {
          await created.end(dismissalPolicy: .immediate); return
        }
        activity = created
        trace("IOS_ACTIVITY_STARTED", "succeeded")
        if !foreground {
          let alert = AlertConfiguration(title: "可信身份来电",
            body: next.showType == 6 ? "此来电身份为未认证身份，建议您谨慎采信" : "来电身份经可信身份认证",
            sound: .default)
          await created.update(using: state, alertConfiguration: alert)
          trace("IOS_ACTIVITY_UPDATED", "succeeded")
        }
        expiration = Task {
          let seconds = max(0, min(1200, next.expiresAt.timeIntervalSinceNow))
          do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
          catch { return }
          guard captured == generation, !Task.isCancelled else { return }
          await created.end(dismissalPolicy: .immediate)
          activity = nil
          trace("IOS_ACTIVITY_ENDED", "cancelled")
        }
      } catch {
        activity = nil
        trace("IOS_ACTIVITY_FAILED", "failed")
      }
    }
  }

  private func compressedAvatar(_ data: Data) -> Data {
    guard data.count <= 32768, let image = UIImage(data: data) else { return Data() }
    // Explicit pixels keep output independent of the device's screen scale.
    // Always draw from the decoded source, not a previously reduced candidate.
    for pixels in [120, 80, 60] {
      let side = CGFloat(pixels)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
      let thumbnail = renderer.image { _ in image.draw(in: CGRect(x: 0, y: 0, width: side, height: side)) }
      for quality in [0.6, 0.35, 0.15] {
        if let result = thumbnail.jpegData(compressionQuality: quality), result.count <= 1536 { return result }
      }
    }
    return Data()
  }

  func resume() { receive(lastReport) }
}
