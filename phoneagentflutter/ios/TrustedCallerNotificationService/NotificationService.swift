import Foundation
import Intents
import UserNotifications
import os

private let incomingLog = Logger(subsystem: "com.chaken.phoneagent", category: "TrustedIncomingNSE")

@objc(NotificationService)
final class NotificationService: UNNotificationServiceExtension {
  private var current: TrustedNotificationDelivery?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    incomingLog.info("NSE_RECEIVED")
    current?.finish()
    let delivery = TrustedNotificationDelivery(content: request.content, handler: contentHandler)
    current = delivery
    delivery.start()
  }

  override func serviceExtensionTimeWillExpire() { incomingLog.info("NSE_EXPIRED"); current?.finish() }
}

/// Each request owns its completion, deadline and bounded ephemeral download.
private final class TrustedNotificationDelivery: NSObject, URLSessionDataDelegate {
  private let original: UNNotificationContent
  private let lock = NSLock()
  private let completion: TrustedNotificationCompletion<UNNotificationContent>
  private var session: URLSession?
  private var bytes = Data()

  init(content: UNNotificationContent, handler: @escaping (UNNotificationContent) -> Void) {
    original = content
    completion = TrustedNotificationCompletion(fallback: content, handler: handler)
  }

  func start() {
    guard TrustedNotificationPolicy.isIncoming(original.userInfo) else { incomingLog.info("NSE_PAYLOAD_REJECTED"); finish(); return }
    incomingLog.info("NSE_PAYLOAD_ACCEPTED")
    DispatchQueue.global().asyncAfter(deadline: .now() + TrustedNotificationPolicy.timeout) { [weak self] in
      guard let self, !self.completion.isFinished else { return }
      incomingLog.info("NSE_DEADLINE"); self.finish()
    }
    guard let url = TrustedNotificationPolicy.avatarURL(original.userInfo["picUrl"]) else {
      decorate(avatar: nil)
      return
    }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = TrustedNotificationPolicy.timeout
    configuration.timeoutIntervalForResource = TrustedNotificationPolicy.timeout
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    lock.lock()
    guard !completion.isFinished else { lock.unlock(); session.invalidateAndCancel(); return }
    self.session = session
    lock.unlock()
    session.dataTask(with: url).resume()
  }

  func finish(_ content: UNNotificationContent? = nil) {
    completion.finish(content) {
      lock.lock()
      let download = session
      session = nil
      lock.unlock()
      download?.invalidateAndCancel()
    }
  }

  private func decorate(avatar: INImage?) {
    guard completion.beginDecoration() else { return }
    let sender = INPerson(
      personHandle: INPersonHandle(value: "", type: .unknown),
      nameComponents: PersonNameComponents(),
      displayName: original.title.isEmpty ? "可信身份来电" : original.title,
      image: avatar, contactIdentifier: nil, customIdentifier: nil,
      isMe: false, suggestionType: .none
    )
    let me = INPerson(
      personHandle: INPersonHandle(value: "", type: .unknown), nameComponents: nil,
      displayName: nil, image: nil, contactIdentifier: nil, customIdentifier: nil,
      isMe: true, suggestionType: .none
    )
    let intent = INSendMessageIntent(
      recipients: [me, sender], outgoingMessageType: .outgoingMessageText,
      content: original.body, speakableGroupName: INSpeakableString(spokenPhrase: ""),
      conversationIdentifier: nil, serviceName: nil, sender: sender, attachments: nil
    )
    if let avatar { intent.setImage(avatar, forParameterNamed: \.speakableGroupName) }
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = .incoming
    interaction.donate { [weak self] error in
      guard let self else { return }
      if error != nil { incomingLog.info("NSE_DONATION_FAILED"); self.finish(); return }
      guard !self.completion.isFinished else { return }
      do { self.finish(try self.original.updating(from: intent)); incomingLog.info("NSE_COMMUNICATION_DELIVERED") }
      catch { incomingLog.info("NSE_CONVERSION_FAILED"); self.finish() }
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    guard let url = request.url, TrustedNotificationPolicy.avatarURL(url.absoluteString) != nil else {
      completionHandler(nil)
      incomingLog.info("NSE_AVATAR_FALLBACK")
      decorate(avatar: nil)
      return
    }
    completionHandler(request)
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask,
    didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
          response.expectedContentLength <= Int64(TrustedNotificationPolicy.maximumAvatarBytes) else {
      completionHandler(.cancel)
      incomingLog.info("NSE_AVATAR_FALLBACK")
      decorate(avatar: nil)
      return
    }
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard TrustedNotificationPolicy.acceptsBytes(received: bytes.count, additional: data.count) else {
      dataTask.cancel()
      bytes.removeAll()
      incomingLog.info("NSE_AVATAR_FALLBACK")
      decorate(avatar: nil)
      return
    }
    bytes.append(data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard error == nil, !bytes.isEmpty else { bytes.removeAll(); incomingLog.info("NSE_AVATAR_FALLBACK"); decorate(avatar: nil); return }
    decorate(avatar: INImage(imageData: bytes))
    bytes.removeAll()
  }
}
