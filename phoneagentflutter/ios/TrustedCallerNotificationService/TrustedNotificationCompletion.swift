import Foundation

/// A request owns one terminal delivery, including expiry and late callbacks.
final class TrustedNotificationCompletion<Value> {
  private let lock = NSLock()
  private let fallback: Value
  private var handler: ((Value) -> Void)?
  private var decorating = false

  init(fallback: Value, handler: @escaping (Value) -> Void) {
    self.fallback = fallback
    self.handler = handler
  }

  var isFinished: Bool {
    lock.lock()
    defer { lock.unlock() }
    return handler == nil
  }

  func beginDecoration() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard handler != nil, !decorating else { return false }
    decorating = true
    return true
  }

  @discardableResult
  func finish(_ value: Value? = nil, cleanup: () -> Void = {}) -> Bool {
    lock.lock()
    guard let callback = handler else { lock.unlock(); return false }
    handler = nil
    lock.unlock()
    cleanup()
    callback(value ?? fallback)
    return true
  }
}
