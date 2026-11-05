import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'fake_commerce_repository.dart';
import 'platform_purchase_fixture.dart';

class PartialRepository extends FakeCommerceRepository {
  bool catalogFails = false, membershipFails = false;
  Completer<CommerceCatalog>? catalogGate;
  Completer<MembershipCurrent>? membershipGate;
  @override
  Future<CommerceCatalog> catalog() async {
    if (catalogFails) throw const CommerceFailure('PRODUCT_UNAVAILABLE');
    return catalogGate?.future ?? platformState().catalog!;
  }

  @override
  Future<MembershipCurrent> membership() async {
    if (membershipFails) {
      throw const CommerceFailure('MEMBERSHIP_SERVICE_UNAVAILABLE');
    }
    return membershipGate?.future ?? platformState().membership!;
  }
}

void main() {
  CatalogController controller(PartialRepository repository) =>
      CatalogController(
        repository,
        FakePaymentLauncher(),
        requiresPlatformProducts: false,
      );

  test(
    'catalog failure retains successful PLUS membership and retry recovers',
    () async {
      final repository = PartialRepository()..catalogFails = true;
      final c = controller(repository);
      addTearDown(c.dispose);
      await c.load();
      expect(c.state.membership?.level, 'PLUS');
      expect(c.state.membership?.benefits?['monthlyBasePoints'], 1234);
      expect(c.state.catalog, isNull);
      expect(c.state.error, contains('商品暂不可购买'));
      expect(c.state.loading, isFalse);
      repository.catalogFails = false;
      await c.load();
      expect(c.state.catalog, isNotNull);
      expect(c.state.error, isEmpty);
      expect(c.state.purchasable(c.state.catalog!.products.first), isTrue);
    },
  );

  test(
    'membership failure retains catalog but blocks checkout until retry',
    () async {
      final repository = PartialRepository()..membershipFails = true;
      final c = controller(repository);
      addTearDown(c.dispose);
      await c.load();
      expect(c.state.catalog?.products.length, 2);
      expect(c.state.membership, isNull);
      expect(c.state.error, contains('会员服务暂不可用'));
      final product = c.state.catalog!.products.first;
      expect(c.state.purchaseEnabled(product), isFalse);
      expect(c.state.purchasable(product), isFalse);
      repository.membershipFails = false;
      await c.load();
      expect(c.state.membership?.level, 'PLUS');
      expect(c.state.purchasable(product), isTrue);
    },
  );

  test(
    'refresh clears previous membership instead of reusing failed identity',
    () async {
      final repository = PartialRepository();
      final c = controller(repository);
      addTearDown(c.dispose);
      await c.load();
      repository.membershipFails = true;
      final refresh = c.load();
      expect(c.state.membership, isNull);
      expect(c.state.channelAvailable, isFalse);
      await refresh;
      expect(c.state.membership, isNull);
      expect(c.state.catalog, isNotNull);
    },
  );

  test('newer load wins over late partially successful read', () async {
    final repository = PartialRepository()
      ..catalogGate = Completer()
      ..membershipGate = Completer();
    final c = controller(repository);
    addTearDown(c.dispose);
    final oldCatalog = repository.catalogGate!;
    final oldMembership = repository.membershipGate!;
    final oldLoad = c.load();
    repository.catalogGate = null;
    repository.membershipGate = null;
    repository.membershipFails = true;
    await c.load();
    oldCatalog.completeError(const CommerceFailure('PRODUCT_UNAVAILABLE'));
    oldMembership.complete(platformState().membership!);
    await oldLoad;
    expect(c.state.catalog, isNotNull);
    expect(c.state.membership, isNull);
    expect(c.state.error, '会员服务暂不可用，请稍后重试');
  });

  test('disposed load ignores successful member and failed catalog', () async {
    final repository = PartialRepository()
      ..catalogGate = Completer()
      ..membershipGate = Completer();
    final c = controller(repository);
    final work = c.load();
    c.dispose();
    repository.catalogGate!.completeError(StateError('synthetic unavailable'));
    repository.membershipGate!.complete(platformState().membership!);
    await work;
  });
}
