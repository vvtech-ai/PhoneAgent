import Flutter
import StoreKit
import StoreKitTest
import Foundation
import XCTest

/// Local StoreKit only: synthetic SKU, no network account or real payment.
final class LocalStoreKitTests: XCTestCase {
  private var session: SKTestSession!
  private var configuration: URL!
  private let sku = "local.phoneagent.points"

  override func setUpWithError() throws {
    configuration = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension("storekit")
    try Data(Self.localConfiguration.utf8).write(to: configuration)
    session = try SKTestSession(contentsOf: configuration)
    session.resetToDefaultState()
    session.clearTransactions()
    session.disableDialogs = true
    session.storefront = "CHN"
    session.locale = Locale(identifier: "zh_CN")
  }

  override func tearDownWithError() throws {
    session?.clearTransactions()
    session?.resetToDefaultState()
    if let configuration { try? FileManager.default.removeItem(at: configuration) }
    session = nil
  }

  @MainActor
  private func call(_ bridge: CommercePaymentChannel, _ method: String,
                    _ arguments: [String: Any]? = nil) async -> Any? {
    await withCheckedContinuation { continuation in
      bridge.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
        continuation.resume(returning: $0)
      }
    }
  }

  @MainActor
  func testLocalProductPriceMismatchAndUnfinishedRecovery() async throws {
    let bridge = CommercePaymentChannel()
    let products = await call(bridge, "products", ["ids": [sku, "local.missing"]]) as? [[String: String]]
    XCTAssertEqual(products?.count, 1)
    let product = try XCTUnwrap(products?.first)
    XCTAssertEqual(product["id"], sku)
    XCTAssertEqual(product["productType"], "consumable")
    XCTAssertEqual(product["currencyCode"], "CNY")
    XCTAssertFalse(try XCTUnwrap(product["displayPrice"]).isEmpty)
    var parameters = ["platformProductId": sku, "appAccountToken": UUID().uuidString,
      "expectedPrice": "999", "expectedCurrency": "CNY", "expectedType": "consumable"]
    let mismatch = await call(bridge, "launch", ["channel": "APPLE_IAP", "parameters": parameters])
    XCTAssertEqual((mismatch as? FlutterError)?.code, "PRICE_CHANGED")
    XCTAssertTrue(session.allTransactions().isEmpty)
    parameters["expectedPrice"] = product["price"]
    let purchased = await call(bridge, "launch", ["channel": "APPLE_IAP", "parameters": parameters]) as? [String: String]
    let id = try XCTUnwrap(purchased?["transactionId"])
    XCTAssertNotNil(purchased?["signedTransaction"])
    let unfinished = await call(bridge, "restore") as? [[String: String]]
    XCTAssertTrue(unfinished?.contains(where: { $0["transactionId"] == id }) == true)
    _ = await call(bridge, "acknowledge", ["transactionId": id])
    let finished = await call(bridge, "restore") as? [[String: String]]
    XCTAssertFalse(finished?.contains(where: { $0["transactionId"] == id }) == true)
  }

  @MainActor
  func testUSStorefrontPurchasesWithoutCNYReferenceParameters() async throws {
    session.storefront = "USA"
    session.locale = Locale(identifier: "en_US")
    let bridge = CommercePaymentChannel()
    let products = await call(bridge, "products", ["ids": [sku]]) as? [[String: String]]
    let product = try XCTUnwrap(products?.first)
    XCTAssertEqual(product["currencyCode"], "USD")
    let parameters = ["platformProductId": sku, "appAccountToken": UUID().uuidString,
      "expectedPrice": try XCTUnwrap(product["price"]),
      "expectedCurrency": try XCTUnwrap(product["currencyCode"]), "expectedType": "consumable"]
    let purchased = await call(bridge, "launch", ["channel": "APPLE_IAP", "parameters": parameters]) as? [String: String]
    XCTAssertNotNil(purchased?["signedTransaction"])
    let id = try XCTUnwrap(purchased?["transactionId"])
    _ = await call(bridge, "acknowledge", ["transactionId": id])
  }

  @MainActor
  func testAskToBuyPendingThenTransactionUpdate() async throws {
    session.askToBuyEnabled = true
    let bridge = CommercePaymentChannel()
    let products = await call(bridge, "products", ["ids": [sku]]) as? [[String: String]]
    let product = try XCTUnwrap(products?.first)
    let parameters = ["platformProductId": sku, "appAccountToken": UUID().uuidString,
      "expectedPrice": try XCTUnwrap(product["price"]), "expectedCurrency": "CNY", "expectedType": "consumable"]
    let pending = await call(bridge, "launch", ["channel": "APPLE_IAP", "parameters": parameters]) as? [String: String]
    XCTAssertEqual(pending?["nativeOutcome"], "PENDING")
    let update = expectation(description: "StoreKit approved transaction notification")
    var initial = true
    _ = bridge.onListen(withArguments: nil) { _ in
      if initial { initial = false } else { update.fulfill() }
    }
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.approveAskToBuyTransaction(identifier: transaction.identifier)
    await fulfillment(of: [update], timeout: 10)
    let unfinished = await call(bridge, "restore") as? [[String: String]]
    XCTAssertFalse(unfinished?.isEmpty ?? true)
    _ = bridge.onCancel(withArguments: nil)
  }

  private static let localConfiguration = #"""
  {
    "identifier": "local-phoneagent-commerce-tests",
    "nonRenewingSubscriptions": [],
    "products": [{
      "displayPrice": "6.00", "familyShareable": false,
      "internalID": "600001",
      "localizations": [{"description": "本地测试积分", "displayName": "测试积分包", "locale": "zh_CN"}],
      "productID": "local.phoneagent.points", "referenceName": "Local points", "type": "Consumable"
    }],
    "settings": {"_applicationInternalID": "", "_developerTeamID": "", "_failTransactionsEnabled": false,
      "_locale": "zh_CN", "_storefront": "CHN", "_storeKitErrors": []},
    "subscriptionGroups": [], "version": {"major": 3, "minor": 0}
  }
  """#
}
