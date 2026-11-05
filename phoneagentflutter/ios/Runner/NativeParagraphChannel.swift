import Flutter
import UIKit

/// Presentation only: no account, audio, network, storage or permission APIs.
@objc(PhoneAgentNativeParagraphChannel)
public final class NativeParagraphChannel: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/native_paragraph", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NativeParagraphChannel(), channel: channel)
    registrar.register(NativeParagraphFactory(messenger: registrar.messenger()), withId: "phone_agent/native_paragraph/view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "measure" else { result(FlutterMethodNotImplemented); return }
    guard let input = ParagraphInput(call.arguments) else {
      result(FlutterError(code: "INVALID_LAYOUT", message: "Invalid paragraph layout", details: nil)); return
    }
    let bounds = input.attributed.boundingRect(
      with: CGSize(width: input.width, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    result(["width": min(input.width, max(1, ceil(bounds.width))),
            "height": max(input.lineHeight, ceil(bounds.height))])
  }
}

private struct ParagraphInput {
  let text: String
  let width: CGFloat
  let fontSize: CGFloat
  let lineHeight: CGFloat
  let color: UIColor
  let rtl: Bool

  init?(_ value: Any?) {
    guard let args = value as? [String: Any], let text = args["text"] as? String,
          let width = args["maxWidth"] as? NSNumber,
          let fontSize = args["fontSize"] as? NSNumber,
          let lineHeight = args["lineHeight"] as? NSNumber else { return nil }
    self.text = text
    self.width = CGFloat(width.doubleValue)
    self.fontSize = CGFloat(fontSize.doubleValue)
    self.lineHeight = CGFloat(lineHeight.doubleValue)
    guard self.width.isFinite, self.fontSize.isFinite, self.lineHeight.isFinite,
          self.width > 0, self.fontSize > 0, self.lineHeight >= self.fontSize else { return nil }
    let argb = (args["color"] as? NSNumber)?.uint32Value ?? 0xff1a1a1a
    color = UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                    green: CGFloat((argb >> 8) & 255) / 255,
                    blue: CGFloat(argb & 255) / 255,
                    alpha: CGFloat((argb >> 24) & 255) / 255)
    rtl = args["direction"] as? String == "rtl"
  }

  var attributed: NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.minimumLineHeight = lineHeight
    paragraph.maximumLineHeight = lineHeight
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    return NSAttributedString(string: text, attributes: [
      .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
      .foregroundColor: color, .paragraphStyle: paragraph
    ])
  }
}

private final class NativeParagraphFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeParagraphView(frame: frame, input: ParagraphInput(args), viewId: viewId, messenger: messenger)
  }
}

private final class NativeParagraphView: NSObject, FlutterPlatformView {
  private let textView: UITextView
  private let channel: FlutterMethodChannel
  private var revision: Int64 = 0
  init(frame: CGRect, input: ParagraphInput?, viewId: Int64, messenger: FlutterBinaryMessenger) {
    textView = UITextView(frame: frame)
    channel = FlutterMethodChannel(name: "phone_agent/native_paragraph/view/\(viewId)", binaryMessenger: messenger)
    super.init()
    textView.backgroundColor = .clear
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.textContainerInset = .zero
    textView.contentInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainer.lineBreakMode = .byWordWrapping
    textView.adjustsFontForContentSizeCategory = false
    // Flutter owns the single complete message semantics node.
    textView.isAccessibilityElement = false
    if let input = input { textView.attributedText = input.attributed }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
      guard let self = self, let args = call.arguments as? [String: Any],
            let revision = args["revision"] as? NSNumber,
            let input = ParagraphInput(args) else {
        result(FlutterError(code: "INVALID_LAYOUT", message: "Invalid paragraph layout", details: nil)); return
      }
      if revision.int64Value > self.revision {
        self.revision = revision.int64Value
        self.textView.attributedText = input.attributed
      }
      result(nil)
    }
  }
  deinit { channel.setMethodCallHandler(nil) }
  func view() -> UIView { textView }
}
