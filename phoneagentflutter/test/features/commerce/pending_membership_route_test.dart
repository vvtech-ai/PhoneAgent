import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:phone_agent/core/design/native_confirmation_dialog.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_route.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_sheet.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'fake_commerce_repository.dart';
import 'pending_membership_controller_test.dart'
    show ClosingRepository, pendingOrder;
import 'purchase_card_fixture.dart';
import 'platform_purchase_fixture.dart';

class _Repo extends ClosingRepository {
  int membershipReads = 0;
  bool salesDisabled = false;
  @override
  Future<CommerceCatalog> catalog() async => salesDisabled
      ? platformState(member: false, points: false).catalog!
      : purchaseCardCatalog(unavailable: false).catalog!;
  @override
  Future<MembershipCurrent> membership() async {
    membershipReads++;
    return MembershipCurrent(
      level: 'FREE',
      entitlementVersionId: 1,
      benefits: const {},
      terms: const [],
      pendingOrderNo: current.unresolved ? 'order-1' : null,
    );
  }
}

class _Wallet implements PointsWalletRepository {
  @override
  Future<PointsAccount> account() async => const PointsAccount(
    totalBalance: 0,
    availableBalance: 0,
    heldBalance: 0,
    updatedAt: 'synthetic',
  );
  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      const PointsLedgerPage(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
      );
}

class _Native extends FakePaymentLauncher {
  final gate = Completer<NativePaymentResult>();
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    return gate.future;
  }
}

Future<PurchaseController> _mount(
  WidgetTester tester,
  _Repo repo, {
  FakePaymentLauncher? launcher,
  StateProvider<int?>? epoch,
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final native = launcher ?? FakePaymentLauncher();
  final controller = PurchaseController(repo, native, paymentChannel: 'ALIPAY');
  await controller.query('order-1');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWith(
          (ref) => epoch == null ? 1 : ref.watch(epoch),
        ),
        commerceRepositoryProvider.overrideWithValue(repo),
        paymentLauncherProvider.overrideWithValue(native),
        purchaseControllerProvider.overrideWith((ref) => controller),
        pointsWalletRepositoryProvider.overrideWithValue(_Wallet()),
        pointsWalletCacheProvider.overrideWithValue(
          const EmptyPointsWalletCache(),
        ),
        pointsBillingProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MembershipRoute(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(find.text('处理待购买事项'));
  await tester.tap(find.text('处理待购买事项'));
  await tester.pumpAndSettle();
  expect(find.text('待处理购买'), findsOneWidget);
  expect(find.byType(PurchaseResultRoute), findsNothing);
  expect(find.text('order-1'), findsNothing);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void _expectCancellationStyle(WidgetTester tester) {
  expect(find.byType(NativeConfirmationDialog), findsOneWidget);
  expect(find.byType(AlertDialog), findsNothing);
  final dialog = tester.widget<NativeBusinessDialog>(
    find.byType(NativeBusinessDialog),
  );
  expect(dialog.kind, NativeDialogKind.confirmation);
  expect(dialog.danger, isTrue);
  for (final entry in {
    '确认取消': NativeActionTone.danger,
    '暂不取消': NativeActionTone.secondary,
  }.entries) {
    final action = tester.widget<NativeGradientAction>(
      find.ancestor(
        of: find.widgetWithText(TextButton, entry.key),
        matching: find.byType(NativeGradientAction),
      ),
    );
    expect(action.tone, entry.value);
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform cancel uses shared style and pauses polling', (
      tester,
    ) async {
      final repo = _Repo()..current = pendingOrder();
      await _mount(tester, repo, platform: platform);
      await _open(tester);
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      _expectCancellationStyle(tester);
      final queries = repo.queries;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.queries, queries);
      expect(repo.closed, isEmpty);
      await tester.tap(find.text('暂不取消'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.queries, greaterThan(queries));
      expect(repo.closed, isEmpty);
      await _dispose(tester);
    });
  }
  testWidgets('disposing initiating route during confirmation never closes', (
    tester,
  ) async {
    final repo = _Repo()..current = pendingOrder();
    await _mount(tester, repo);
    await _open(tester);
    await tester.tap(find.text('取消本次购买'));
    await tester.pumpAndSettle();
    _expectCancellationStyle(tester);
    await _dispose(tester);
    expect(repo.closed, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'disabled new sales still permits original purchase query and retry',
    (tester) async {
      final repo = _Repo()
        ..current = pendingOrder()
        ..salesDisabled = true;
      final native = FakePaymentLauncher();
      await _mount(tester, repo, launcher: native);
      expect(find.text('+ 购买积分'), findsNothing);
      expect(find.text('购买会员'), findsNothing);
      await _open(tester);
      await tester.tap(find.text('继续支付'));
      await tester.pumpAndSettle();
      expect(native.launches, 1);
      expect(repo.createCalls, 0);
      expect(find.byType(PurchaseFeedbackSheet), findsOneWidget);
      await _dispose(tester);
    },
  );
  testWidgets(
    '320 wide with large text keeps cancel, confirmation and return reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo()..current = pendingOrder();
      await _mount(tester, repo, textScale: 2);
      await _open(tester);
      await tester.ensureVisible(find.text('取消本次购买'));
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('暂不取消'));
      _expectCancellationStyle(tester);
      await tester.tap(find.text('暂不取消'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('稍后再说'));
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repo.closed, isEmpty);
      await _dispose(tester);
    },
  );
  testWidgets(
    'account changes during cancellation confirmation cannot close old purchase',
    (tester) async {
      final repo = _Repo()..current = pendingOrder();
      final epoch = StateProvider<int?>((ref) => 1);
      await _mount(tester, repo, epoch: epoch);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MembershipRoute)),
      );
      await _open(tester);
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      container.read(epoch.notifier).state = 2;
      await tester.pumpAndSettle();
      _expectCancellationStyle(tester);
      await tester.tap(find.text('确认取消'));
      await tester.pumpAndSettle();
      expect(repo.closed, isEmpty);
      await _dispose(tester);
    },
  );
  testWidgets(
    'cancel requires confirmation then trusted close refreshes membership and allows quote',
    (tester) async {
      final repo = _Repo()
        ..current = pendingOrder()
        ..closeResult = pendingOrder(payment: 'CLOSED');
      final controller = await _mount(tester, repo);
      await _open(tester);
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      expect(repo.closed, isEmpty);
      _expectCancellationStyle(tester);
      await tester.tap(find.text('暂不取消'));
      await tester.pumpAndSettle();
      expect(repo.closed, isEmpty);
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认取消'));
      await tester.pumpAndSettle();
      expect(repo.closed, ['order-1']);
      expect(find.text('待处理购买'), findsNothing);
      expect(find.text('处理待购买事项'), findsNothing);
      expect(repo.membershipReads, greaterThan(1));
      await controller.preview('another-plan', 1, agreementAccepted: true);
      expect(repo.quoteCalls, 1);
      expect(repo.createCalls, 0);
      await _dispose(tester);
    },
  );
  testWidgets(
    'persisted cancel pending across fresh route offers only query and return',
    (tester) async {
      final repo = _Repo()
        ..current = pendingOrder(code: 'PAYMENT_CANCELLATION_PENDING');
      final native = FakePaymentLauncher();
      await _mount(tester, repo, launcher: native);
      await _open(tester);
      expect(find.text('取消处理中，请稍后查看'), findsOneWidget);
      expect(find.text('继续支付'), findsNothing);
      expect(find.text('取消本次购买'), findsNothing);
      final queries = repo.queries;
      await tester.tap(find.text('刷新状态'));
      await tester.pumpAndSettle();
      expect(repo.queries, queries + 1);
      expect(native.launches, 0);
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      expect(find.text('处理待购买事项'), findsOneWidget);
      await _dispose(tester);
    },
  );
  testWidgets(
    'close awaiting trustworthy provider fact keeps pending without success claim',
    (tester) async {
      final repo = _Repo()
        ..current = pendingOrder()
        ..closeResult = pendingOrder(code: 'PAYMENT_CANCELLATION_PENDING');
      await _mount(tester, repo);
      await _open(tester);
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认取消'));
      await tester.pumpAndSettle();
      expect(find.text('取消处理中，请稍后查看'), findsOneWidget);
      expect(find.text('已取消'), findsNothing);
      expect(find.text('继续支付'), findsNothing);
      expect(repo.current.unresolved, isTrue);
      await _dispose(tester);
    },
  );
  testWidgets(
    'legacy unknown close keeps original retry and safe pending explanation',
    (tester) async {
      final repo = _Repo()..current = pendingOrder();
      await _mount(tester, repo);
      await _open(tester);
      await tester.tap(find.text('取消本次购买'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认取消'));
      await tester.pumpAndSettle();
      expect(find.text('取消结果尚未确认，请稍后刷新状态。'), findsOneWidget);
      expect(find.text('继续支付'), findsOneWidget);
      expect(repo.current.unresolved, isTrue);
      await _dispose(tester);
    },
  );
  testWidgets(
    'retry waits privately then feedback shows only attempt and done',
    (tester) async {
      final repo = _Repo()..current = pendingOrder();
      final native = _Native();
      await _mount(tester, repo, launcher: native);
      await _open(tester);
      await tester.tap(find.text('继续支付'));
      await tester.pump();
      expect(native.launches, 1);
      expect(find.text('待处理购买'), findsNothing);
      expect(find.text('刷新状态'), findsNothing);
      expect(find.text('取消本次购买'), findsNothing);
      expect(find.text('order-1'), findsNothing);
      native.gate.complete(
        const NativePaymentResult(nativeResultStatus: '6001'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseFeedbackSheet), findsOneWidget);
      expect(find.text('支付已取消'), findsOneWidget);
      expect(find.text('继续支付'), findsNothing);
      expect(find.text('刷新状态'), findsNothing);
      expect(find.text('order-1'), findsNothing);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('待处理购买'), findsNothing);
      expect(repo.createCalls, 0);
      await _dispose(tester);
    },
  );
  testWidgets(
    'trusted paid overrides stale cancel code and prevents cancellation',
    (tester) async {
      final repo = _Repo()..current = pendingOrder();
      await _mount(tester, repo);
      repo.current = pendingOrder(
        payment: 'SUCCEEDED',
        paid: 3000,
        code: 'PAYMENT_CANCELLATION_PENDING',
      );
      await _open(tester);
      expect(find.text('已支付，权益处理中'), findsOneWidget);
      expect(find.text('取消处理中，请稍后查看'), findsNothing);
      expect(find.text('取消本次购买'), findsNothing);
      expect(find.text('继续支付'), findsNothing);
      await _dispose(tester);
    },
  );
  testWidgets(
    'member refresh also refreshes stale purchase blocker after server failure',
    (tester) async {
      final repo = _Repo()..current = pendingOrder();
      final controller = await _mount(tester, repo);
      repo.current = pendingOrder(payment: 'FAILED');
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(controller.snapshot.order?.paymentState, 'FAILED');
      expect(find.text('处理待购买事项'), findsNothing);
      await controller.preview('m2', 1, agreementAccepted: true);
      expect(repo.quoteCalls, 1);
      await _dispose(tester);
    },
  );
}
