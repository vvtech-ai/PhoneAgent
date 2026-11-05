import '../../domain/commerce_catalog.dart';
import '../../data/commerce_diagnostics.dart';
import 'catalog_controller.dart';
import 'purchase_controller.dart';

enum CheckoutOutcome { canceled, purchase, error, stale }

class MembershipCheckout {
  MembershipCheckout(this.purchase);
  final PurchaseController purchase;
  bool upgrade = false;
  Future<CheckoutOutcome> buy(
    ProductOffer product,
    CatalogState catalog, {
    required Future<bool> Function(CommerceQuote quote) confirm,
    required bool Function() isCurrent,
  }) async {
    final log = purchase.diagnostics;
    log?.event(
      CommerceStage.selection,
      DiagnosticResult.received,
      productId: product.productId,
      sku: product.platformProductId ?? '',
    );
    final directory = catalog.catalog;
    if (!isCurrent()) return CheckoutOutcome.stale;
    if (directory == null || purchase.snapshot.busy) {
      return CheckoutOutcome.error;
    }
    if (!catalog.purchaseEnabled(product)) return CheckoutOutcome.error;
    final apple = catalog.platformProducts[product.platformProductId];
    if (catalog.requiresPlatformProducts &&
        (!catalog.purchasable(product) ||
            apple == null ||
            !apple.supports(product.productType))) {
      log?.product(product, apple, false);
      return CheckoutOutcome.error;
    }
    if (!catalog.agreementAccepted) {
      log?.event(
        CommerceStage.agreement,
        DiagnosticResult.failed,
        reason: CommerceReason.agreementRequired,
        productId: product.productId,
      );
    }
    await purchase.preview(
      product.productId,
      directory.configVersionId,
      agreementAccepted: catalog.agreementAccepted,
    );
    if (!isCurrent()) return CheckoutOutcome.stale;
    final quote = purchase.snapshot.quote;
    if (quote == null || purchase.snapshot.error.isNotEmpty) {
      return CheckoutOutcome.error;
    }
    upgrade = quote.purchaseType == 'UPGRADE';
    if (catalog.requiresPlatformProducts &&
        (quote.productId != product.productId ||
            quote.configVersionId != directory.configVersionId)) {
      log?.event(
        CommerceStage.priceCheck,
        DiagnosticResult.failed,
        reason: CommerceReason.priceChanged,
        productId: product.productId,
        quoteId: quote.quoteId,
      );
      return CheckoutOutcome.error;
    }
    log?.event(
      CommerceStage.confirmation,
      DiagnosticResult.started,
      productId: product.productId,
      quoteId: quote.quoteId,
    );
    final accepted = await confirm(quote);
    log?.event(
      CommerceStage.confirmation,
      accepted ? DiagnosticResult.succeeded : DiagnosticResult.cancelled,
      productId: product.productId,
      quoteId: quote.quoteId,
      state: accepted ? 'accepted' : 'declined',
    );
    if (!isCurrent()) return CheckoutOutcome.stale;
    if (!accepted) return CheckoutOutcome.canceled;
    if (purchase.snapshot.quote?.quoteId != quote.quoteId ||
        purchase.snapshot.quote?.productId != quote.productId) {
      return CheckoutOutcome.stale;
    }
    if (catalog.requiresPlatformProducts) {
      if (!await purchase.prepareApplePurchase(product, apple!)) {
        if (!isCurrent()) return CheckoutOutcome.stale;
        return purchase.snapshot.recoveredPreviousPurchase
            ? CheckoutOutcome.purchase
            : CheckoutOutcome.error;
      }
      if (!isCurrent() ||
          purchase.snapshot.quote?.quoteId != quote.quoteId ||
          purchase.snapshot.quote?.productId != quote.productId) {
        return CheckoutOutcome.stale;
      }
    }
    await purchase.confirmPurchase(
      directory.agreementVersion,
      agreementAccepted: accepted,
      isCurrent: isCurrent,
    );
    upgrade = upgrade && purchase.snapshot.order?.quoteId == quote.quoteId;
    if (!isCurrent()) return CheckoutOutcome.stale;
    return purchase.snapshot.order == null
        ? CheckoutOutcome.error
        : CheckoutOutcome.purchase;
  }
}
