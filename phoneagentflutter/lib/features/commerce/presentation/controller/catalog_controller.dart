import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/commerce_diagnostics.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/membership_purchase_eligibility.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/payment_launcher.dart';
import 'catalog_read_result.dart';

enum PlatformProductsStatus { idle, loading, ready, failed }

class CatalogState {
  const CatalogState({
    this.catalog,
    this.membership,
    this.loading = false,
    this.error = '',
    this.selectedLevel = 'BASIC',
    int selectedMonths = 1,
    this.agreementAccepted = false,
    this.channelAvailable = false,
    this.platformProducts = const {},
    this.requiresPlatformProducts = false,
    this.platformStatus = PlatformProductsStatus.idle,
  }) : _selectedMonths = selectedMonths;
  final PlatformProductsStatus platformStatus;
  final CommerceCatalog? catalog;
  final MembershipCurrent? membership;
  final bool loading,
      agreementAccepted,
      channelAvailable,
      requiresPlatformProducts;
  final String error, selectedLevel;
  final int _selectedMonths;
  final Map<String, PlatformProduct> platformProducts;
  bool get unconfigured {
    final value = catalog;
    return value != null &&
        value.configVersionId == 0 &&
        value.revisionNo == 0 &&
        value.products.isEmpty &&
        value.benefitsByLevel.isEmpty;
  }

  List<ProductOffer> visibleOffers(String type) => (catalog?.products ?? [])
      .where((p) => p.productType == type && p.available && _salesEnabled(p))
      .toList();
  List<ProductOffer> get offers =>
      visibleOffers(
          'MEMBERSHIP',
        ).where((p) => p.level == selectedLevel).toList()
        ..sort((a, b) => (a.months ?? 0).compareTo(b.months ?? 0));
  int get selectedMonths {
    final available = offers;
    if (available.isEmpty ||
        available.any((p) => p.months == _selectedMonths)) {
      return _selectedMonths;
    }
    return available.first.months ?? _selectedMonths;
  }

  ProductOffer? get selectedProduct {
    final matches = offers.where((p) => p.months == selectedMonths);
    return matches.isEmpty ? null : matches.first;
  }

  bool _salesEnabled(ProductOffer product) => switch (product.productType) {
    'MEMBERSHIP' => catalog?.membershipEnabled == true,
    'POINTS_PACK' => catalog?.pointsPackEnabled == true,
    _ => false,
  };
  bool purchaseEnabled(ProductOffer product) =>
      !loading && error.isEmpty && _salesEnabled(product);

  // Keep ongoing checkout/account checks independent of new-purchase eligibility.
  bool newPurchaseEnabled(ProductOffer product) =>
      purchaseEnabled(product) &&
      (product.productType != 'MEMBERSHIP' ||
          MembershipPurchaseEligibility.resolve(membership, product).allowed);

  bool purchasable(ProductOffer p) =>
      newPurchaseEnabled(p) &&
      p.available &&
      channelAvailable &&
      (!requiresPlatformProducts ||
          (p.channel == 'APPLE_IAP' &&
              platformStatus != PlatformProductsStatus.loading &&
              platformStatus != PlatformProductsStatus.failed &&
              platformProducts[p.platformProductId]?.supports(p.productType) ==
                  true));
  String price(ProductOffer p) => requiresPlatformProducts
      ? !p.available ||
                (platformProducts[p.platformProductId]?.productType != null &&
                    !platformProducts[p.platformProductId]!.supports(
                      p.productType,
                    ))
            ? '暂不可售'
            : platformStatus == PlatformProductsStatus.failed
            ? '重新加载'
            : platformProducts[p.platformProductId]?.displayPrice ?? '暂不可售'
      : money(p.cashAmountFen, currency: p.currency);
  CatalogState copy({
    String? error,
    String? selectedLevel,
    int? selectedMonths,
    bool? agreementAccepted,
    bool? channelAvailable,
    PlatformProductsStatus? platformStatus,
    Map<String, PlatformProduct>? platformProducts,
    MembershipCurrent? membership,
  }) => CatalogState(
    catalog: catalog,
    membership: membership ?? this.membership,
    loading: loading,
    error: error ?? this.error,
    selectedLevel: selectedLevel ?? this.selectedLevel,
    selectedMonths: selectedMonths ?? this.selectedMonths,
    agreementAccepted: agreementAccepted ?? this.agreementAccepted,
    channelAvailable: channelAvailable ?? this.channelAvailable,
    platformProducts: platformProducts ?? this.platformProducts,
    platformStatus: platformStatus ?? this.platformStatus,
    requiresPlatformProducts: requiresPlatformProducts,
  );
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(
    this.repository,
    this.launcher, {
    required this.requiresPlatformProducts,
    this.diagnostics,
  }) : super(CatalogState(requiresPlatformProducts: requiresPlatformProducts));
  final CommerceDiagnostics? diagnostics;
  final CommerceRepository repository;
  final PaymentLauncher launcher;
  final bool requiresPlatformProducts;
  int _revision = 0;
  int _membershipRevision = 0;

  /// Refresh only current-account rights; keep the active selection and Apple quote UI.
  Future<bool> refreshMembership() async {
    if (!mounted || state.loading) return false;
    final revision = _revision, membershipRevision = ++_membershipRevision;
    try {
      final membership = await repository.membership();
      if (!mounted ||
          revision != _revision ||
          membershipRevision != _membershipRevision) {
        return false;
      }
      state = state.copy(membership: membership);
      return true;
    } catch (error) {
      diagnostics?.event(
        CommerceStage.catalog,
        DiagnosticResult.failed,
        error: error,
      );
      return false;
    }
  }

  Future<void> load() async {
    final revision = ++_revision;
    final timer = Stopwatch()..start();
    diagnostics?.event(CommerceStage.catalog, DiagnosticResult.started);
    state = CatalogState(
      loading: true,
      requiresPlatformProducts: requiresPlatformProducts,
    );
    final catalogRead = CatalogReadResult.read(
      repository.catalog,
      '商品目录加载失败，请重试',
    );
    final membershipRead = CatalogReadResult.read(
      repository.membership,
      '当前会员加载失败，请重试',
    );
    final catalogResult = await catalogRead;
    final membershipResult = await membershipRead;
    if (!mounted || revision != _revision) return;
    final catalog = catalogResult.value;
    final membership = membershipResult.value;
    final error = [
      catalogResult.error,
      membershipResult.error,
    ].where((message) => message.isNotEmpty).join('\n');
    diagnostics?.event(
      CommerceStage.catalog,
      error.isEmpty ? DiagnosticResult.succeeded : DiagnosticResult.failed,
      found: catalog?.products.length,
      elapsedMs: timer.elapsedMilliseconds,
    );
    state = CatalogState(
      catalog: catalog,
      membership: membership,
      error: error,
      selectedLevel: membership == null || membership.level == 'FREE'
          ? 'BASIC'
          : membership.level,
      selectedMonths: membership?.currentMonths ?? 1,
      requiresPlatformProducts: requiresPlatformProducts,
    );
    if (catalog == null) return;
    if (requiresPlatformProducts) {
      await _loadPlatformProducts(revision);
    } else {
      final available = await CatalogReadResult.read(
        () async => catalog.products.isNotEmpty && await launcher.available(),
        '支付渠道加载失败，请重试',
      );
      if (mounted && revision == _revision) {
        state = state.copy(
          channelAvailable: available.value == true,
          error: [
            error,
            available.error,
          ].where((message) => message.isNotEmpty).join('\n'),
        );
      }
    }
  }

  Future<void> reloadPlatformProducts() async {
    if (!mounted ||
        !requiresPlatformProducts ||
        state.catalog == null ||
        state.platformStatus == PlatformProductsStatus.loading) {
      return;
    }
    diagnostics?.event(CommerceStage.products, DiagnosticResult.received);
    await _loadPlatformProducts(++_revision);
  }

  Future<void> _loadPlatformProducts(int revision) async {
    final ids = state.catalog!.products
        .expand((p) => [p.platformProductId, p.regularPlatformProductId])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    state = state.copy(
      platformStatus: PlatformProductsStatus.loading,
      platformProducts: {},
      channelAvailable: false,
    );
    try {
      final available =
          state.catalog!.products.isNotEmpty && await launcher.available();
      final products = available && ids.isNotEmpty
          ? await launcher.products(ids)
          : <String, PlatformProduct>{};
      if (!mounted || revision != _revision) return;
      state = state.copy(
        platformStatus: PlatformProductsStatus.ready,
        channelAvailable: available,
        platformProducts: Map.unmodifiable(products),
      );
      for (final offer in state.catalog!.products) {
        diagnostics?.product(
          offer,
          products[offer.platformProductId],
          state.purchasable(offer),
        );
      }
    } catch (error) {
      diagnostics?.event(
        CommerceStage.products,
        DiagnosticResult.failed,
        error: error,
      );
      if (mounted && revision == _revision) {
        state = state.copy(
          platformStatus: PlatformProductsStatus.failed,
          platformProducts: {},
          channelAvailable: false,
        );
      }
    }
  }

  void selectLevel(String level) {
    if (membershipLevels.contains(level)) {
      state = state.copy(selectedLevel: level);
    }
  }

  void selectMonths(int months) => state = state.copy(selectedMonths: months);
  void agreement(bool value) {
    diagnostics?.event(
      CommerceStage.agreement,
      DiagnosticResult.received,
      state: value ? 'accepted' : 'declined',
    );
    state = state.copy(agreementAccepted: value);
  }
}
