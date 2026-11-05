import Flutter
import StoreKit

/// StoreKit only. Transactions remain unfinished until the server accepts them.
final class CommercePaymentChannel: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var pending = [UInt64: Transaction]()
  private var launching = false
  private var updates: Task<Void, Never>?
  private var sink: FlutterEventSink?
  override init() {
    super.init()
    updates = Task { @MainActor [weak self] in
      for await verification in Transaction.updates {
        guard !Task.isCancelled else { return }
        if self?.material(verification) != nil {
          self?.diagnostic("transactionUpdate", "verified")
          self?.sink?(true)
        } else { self?.diagnostic("transactionUpdate", "rejected") }
      }
    }
  }
  deinit { updates?.cancel() }
  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    updates?.cancel()
    sink = nil
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    events(true) // Also discover updates received before Dart subscribed.
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "phone_agent/commerce_payment", binaryMessenger: registrar.messenger())
    let instance = CommercePaymentChannel()
    registrar.addMethodCallDelegate(instance, channel: channel)
    FlutterEventChannel(name: "phone_agent/commerce_transactions", binaryMessenger: registrar.messenger())
      .setStreamHandler(instance)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "available": result(SKPaymentQueue.canMakePayments())
    case "products":
      guard let args = call.arguments as? [String: Any], let ids = args["ids"] as? [String] else { fail(result, stage: "productsArguments"); return }
      diagnostic("products", "started")
      Task { @MainActor [self] in
        do {
          let products = try await Product.products(for: ids)
          let supported = products.filter { $0.type == .consumable || $0.type == .nonRenewable }
          NSLog("COMMERCE_NATIVE stage=products result=succeeded found=%ld supported=%ld", products.count, supported.count)
          result(supported.map { ["id": $0.id, "displayPrice": $0.displayPrice,
              "price": NSDecimalNumber(decimal: $0.price).stringValue,
              "currencyCode": $0.priceFormatStyle.currencyCode,
              "productType": $0.type == .consumable ? "consumable" : "nonRenewable"] })
        } catch { fail(result, stage: "products", error: error) }
      }
    case "launch": launch(call, result)
    case "restore":
      Task { @MainActor [self] in
        var materials = [[String: String]]()
        for await verification in Transaction.unfinished {
          if let material = material(verification) { materials.append(material) }
        }
        if !materials.isEmpty { NSLog("COMMERCE_NATIVE stage=restore result=found count=%ld", materials.count) }
        result(materials)
      }
    case "acknowledge":
      guard let args = call.arguments as? [String: Any], let raw = args["transactionId"] as? String,
            let id = UInt64(raw), let transaction = pending[id] else { fail(result, stage: "finishLookup"); return }
      Task { @MainActor [self] in
        diagnostic("finish", "started")
        await transaction.finish()
        pending.removeValue(forKey: id)
        diagnostic("finish", "succeeded")
        result(nil)
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func launch(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard !launching, SKPaymentQueue.canMakePayments(), let args = call.arguments as? [String: Any],
          args["channel"] as? String == "APPLE_IAP", let parameters = args["parameters"] as? [String: String],
          let productID = parameters["platformProductId"], !productID.isEmpty,
          let rawToken = parameters["appAccountToken"], let token = UUID(uuidString: rawToken) else { fail(result, stage: "purchaseGate"); return }
    diagnostic("purchase", "started")
    launching = true
    Task { @MainActor [self] in
      defer { launching = false }
      do {
        guard let product = try await Product.products(for: [productID]).first(where: { $0.id == productID }),
              product.type == .consumable || product.type == .nonRenewable else { fail(result, stage: "productUnavailable"); return }
        guard let expectedPrice = parameters["expectedPrice"],
              let expectedCurrency = parameters["expectedCurrency"],
              let expectedType = parameters["expectedType"],
              let price = Decimal(string: expectedPrice, locale: Locale(identifier: "en_US_POSIX")),
              price == product.price, expectedCurrency == product.priceFormatStyle.currencyCode,
              expectedType == (product.type == .consumable ? "consumable" : "nonRenewable") else {
          diagnostic("priceCheck", "changed")
          result(FlutterError(code: "PRICE_CHANGED", message: "商品价格已变化，请刷新后重新确认", details: nil))
          return
        }
        switch try await product.purchase(options: [.appAccountToken(token)]) {
        case .success(let verification):
          // Only diagnostics change: keep the original validation order and rejection behavior.
          guard case .verified(let transaction) = verification else {
            if case .unverified(let transaction, _) = verification {
              fail(result, stage: "verificationUnverified", transaction: transaction)
            } else { fail(result, stage: "verificationUnverified") }
            return
          }
          guard transaction.productID == productID else {
            fail(result, stage: "verificationProductMismatch", transaction: transaction); return
          }
          guard transaction.appAccountToken != nil else {
            fail(result, stage: "verificationTokenMissing", transaction: transaction); return
          }
          // A verified old transaction is recovery evidence, never authorization for this order.
          // Dart routes a different token through the server-owned original-order verifier.
          if transaction.appAccountToken != token {
            diagnostic("originalTransactionRecovery", "received")
          }
          guard let data = material(verification) else {
            fail(result, stage: "verificationTypeUnsupported", transaction: transaction); return
          }
          diagnostic("purchase", "verifiedMaterial")
          result(data)
        case .pending: diagnostic("purchase", "pending"); result(["nativeOutcome": "PENDING"])
        case .userCancelled: diagnostic("purchase", "cancelled"); result(["nativeOutcome": "CANCELED"])
        @unknown default: fail(result)
        }
      } catch { fail(result, stage: "purchase", error: error) }
    }
  }
  private func material(_ verification: VerificationResult<Transaction>) -> [String: String]? {
    guard case .verified(let transaction) = verification,
          transaction.productType == .consumable || transaction.productType == .nonRenewable,
          let token = transaction.appAccountToken else { return nil }
    pending[transaction.id] = transaction
    return ["transactionId": String(transaction.id), "signedTransaction": verification.jwsRepresentation,
      "appAccountToken": token.uuidString, "platformProductId": transaction.productID]
  }
  private func diagnostic(_ stage: String, _ outcome: String) {
    NSLog("COMMERCE_NATIVE stage=%@ result=%@", stage, outcome)
  }
  private func fail(_ reply: FlutterResult, stage: String = "validation", error: Error? = nil, transaction: Transaction? = nil) {
    let native = error as NSError?
    let allowed = ["SKErrorDomain", "StoreKit.StoreKitError", "NSURLErrorDomain", "SKInternalErrorDomain"]
    let domain = native.map { allowed.contains($0.domain) ? $0.domain : "other" } ?? ""
    let code = native.map { max(-999999, min(999999, $0.code)) } ?? 0
    NSLog("COMMERCE_NATIVE stage=%@ result=failed code=%ld domain=%@", stage, code, domain)
    var details: [String: Any] = ["nativeStage": stage, "nativeDomain": domain, "nativeCode": code]
    // Memory-only bridge metadata; Dart hashes IDs before journal/console output.
    if let transaction = transaction {
      details["transactionId"] = String(transaction.id)
      details["platformProductId"] = transaction.productID
    }
    reply(FlutterError(code: "CHANNEL_UNAVAILABLE", message: "购买结果待确认，请查询原订单",
      details: details))
  }
}
