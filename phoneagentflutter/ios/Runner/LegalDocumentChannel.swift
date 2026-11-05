import Flutter
import SafariServices
import UIKit

/// Fixed public documents, independent from authentication credentials.
final class LegalDocumentChannel: NSObject, FlutterPlugin {
  private weak var host: UIViewController?

  static func register(with registrar: FlutterPluginRegistrar) {
    register(with: registrar, host: nil)
  }

  static func register(with registrar: FlutterPluginRegistrar, host: UIViewController?) {
    let instance = LegalDocumentChannel()
    instance.host = host
    let channel = FlutterMethodChannel(name: "phone_agent/legal_documents", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "openPublishedAgreement" {
      guard let raw = call.arguments as? String, let url = URL(string: raw),
            url.scheme == "https", !(url.host ?? "").isEmpty, url.user == nil, url.password == nil else {
        result(FlutterError(code: "INVALID_DOCUMENT", message: "协议无效", details: nil)); return
      }
      present(url, result)
      return
    }
    guard call.method == "open" else { result(FlutterMethodNotImplemented); return }
    let paths = [
      "userAgreement": "Phone_Agent_user_agreement.html",
      "privacyPolicy": "Phone_Agent_privacy_policy.html",
      "personalInformation": "Phone_Agent_personal_Info.html"
    ]
    guard let key = call.arguments as? String, let path = paths[key],
          let url = URL(string: "https://www.chaken.ai/agreements/" + path) else {
      result(FlutterError(code: "INVALID_DOCUMENT", message: "协议无效", details: nil)); return
    }
    present(url, result)
  }
  private func present(_ url: URL, _ result: @escaping FlutterResult) {
    guard var presenter = host, presenter.view.window != nil else {
      result(FlutterError(code: "UNAVAILABLE", message: "暂时无法打开协议", details: nil)); return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    presenter.present(SFSafariViewController(url: url), animated: true) { result(nil) }
  }
}
