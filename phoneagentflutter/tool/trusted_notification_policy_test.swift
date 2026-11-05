import Foundation

@main
struct TrustedNotificationTests {
  static func main() {
    let valid: [AnyHashable: Any] = ["token": "synthetic", "phoneno": "12025550101", "targetNumber": 12025550102, "sequence": "synthetic-sequence"]
    precondition(TrustedNotificationPolicy.isIncoming(valid))
    for key in ["token", "phoneno", "targetNumber", "sequence"] {
      var missing = valid
      missing.removeValue(forKey: key)
      precondition(!TrustedNotificationPolicy.isIncoming(missing))
      missing[key] = true
      precondition(!TrustedNotificationPolicy.isIncoming(missing))
      missing[key] = "in\u{0000}valid"
      precondition(!TrustedNotificationPolicy.isIncoming(missing))
    }
    for url in ["http://example.invalid/a", "https:///a", "https://user:password@example.invalid/a", "file:///tmp/a", ""] {
      precondition(TrustedNotificationPolicy.avatarURL(url) == nil)
    }
    precondition(TrustedNotificationPolicy.avatarURL("https://example.invalid/a.png") != nil)
    let limit = TrustedNotificationPolicy.maximumAvatarBytes
    precondition(TrustedNotificationPolicy.acceptsBytes(received: 0, additional: limit))
    precondition(!TrustedNotificationPolicy.acceptsBytes(received: limit, additional: 1))
    precondition(!TrustedNotificationPolicy.acceptsBytes(received: 1, additional: Int.max))
    precondition(!TrustedNotificationPolicy.acceptsBytes(received: -1, additional: 0))
    var delivered = [String]()
    var cleanups = 0
    let completion = TrustedNotificationCompletion(fallback: "original") { delivered.append($0) }
    precondition(completion.beginDecoration())
    precondition(!completion.beginDecoration())
    precondition(completion.finish(cleanup: { cleanups += 1 }))
    precondition(!completion.finish("late", cleanup: { cleanups += 1 }))
    precondition(!completion.beginDecoration())
    precondition(completion.isFinished)
    precondition(delivered == ["original"] && cleanups == 1)
    let group = DispatchGroup()
    let concurrent = TrustedNotificationCompletion(fallback: "original") { value in
      precondition(value == "original")
      cleanups += 1
    }
    for _ in 0..<100 {
      group.enter()
      DispatchQueue.global().async { concurrent.finish(); group.leave() }
    }
    group.wait()
    precondition(cleanups == 2)
    print("Trusted notification policy and terminal delivery assertions passed; no network or Intents donation.")
  }
}
