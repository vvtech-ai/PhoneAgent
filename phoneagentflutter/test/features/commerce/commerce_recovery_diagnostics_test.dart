import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/data/commerce_diagnostics.dart';
import 'package:phone_agent/features/commerce/data/diagnostic_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'commerce_recovery_transport.dart';
import 'fake_commerce_repository.dart';

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'actual $platform provider decorates quote502 with safe HTTP cause',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final server = CommerceRecoveryTransport()..quoteStatus = 502;
        addTearDown(server.api.close);
        final journal = DiagnosticJournal(
          _Store(),
          flushDelay: const Duration(days: 1),
        );
        final container = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            accountApiProvider.overrideWithValue(server.api),
            diagnosticJournalProvider.overrideWithValue(journal),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(journal.close);
        final hold = container.listen(commerceRepositoryProvider, (_, __) {});
        addTearDown(hold.close);
        await expectLater(
          container.read(commerceRepositoryProvider).quote('BASIC', 1),
          throwsA(isA<CommerceFailure>()),
        );
        final events = (await journal.snapshot()).events;
        final failures = events.where(
          (e) => e.result == DiagnosticResult.failed,
        );
        expect(failures, hasLength(1));
        expect(failures.single.statusCode, 502);
        expect(
          failures.single.commerce?.businessCode,
          'COMMERCE_SERVICE_UNAVAILABLE',
        );
        expect(failures.single.commerce?.reason, CommerceReason.unavailable);
        final ref = failures.single.commerce!.toJson()['requestRef'];
        expect(ref, matches(RegExp(r'^[a-f0-9]{16}$')));
        expect(events.first.commerce!.toJson()['requestRef'], ref);
        expect(
          jsonEncode(events.map((e) => e.toJson()).toList()),
          isNot(contains('private-provider-body')),
        );
      },
    );
  }
  test(
    'production purchase stages preserve request identities and fulfillment facts',
    () async {
      final server = CommerceRecoveryTransport();
      addTearDown(server.api.close);
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      final repo = DiagnosticCommerceRepository(
        ApiCommerceRepository(server.api),
        log,
      );
      final purchase = PurchaseController(
        repo,
        FakePaymentLauncher(),
        paymentChannel: 'ALIPAY',
        diagnostics: log,
      );
      addTearDown(purchase.dispose);
      await purchase.preview('BASIC', 1, agreementAccepted: true);
      await purchase.confirmPurchase('v1');
      await repo.membership();
      expect(purchase.snapshot.order?.fulfillmentState, 'SUCCEEDED');
      final stages = events.map((e) => e.commerce!.stage.name).toSet();
      expect(
        stages,
        containsAll([
          'quote',
          'createOrder',
          'paymentMaterial',
          'nativePurchase',
          'query',
          'fulfillment',
          'refresh',
        ]),
      );
      final create = events.firstWhere(
        (e) => e.commerce!.stage == CommerceStage.createOrder,
      );
      expect(
        create.commerce!.toJson()['requestRef'],
        CommerceDiagnostics.reference(server.requestIds.single),
      );
      final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
      for (final raw in [
        'order-1',
        server.requestIds.single,
        'private-signature',
        'private-provider-body',
        'synthetic',
      ]) {
        expect(encoded, isNot(contains(raw)));
      }
      final decoded = DiagnosticEvent.fromJson(events.last.toJson());
      expect(
        decoded.commerce!.toJson()['requestRef'],
        events.last.commerce!.toJson()['requestRef'],
      );
    },
  );
  test(
    'broken diagnostic sink cannot change purchase or retry a payment',
    () async {
      final server = CommerceRecoveryTransport();
      addTearDown(server.api.close);
      final log = CommerceDiagnostics((_) => throw StateError('private-token'));
      final repo = DiagnosticCommerceRepository(
        ApiCommerceRepository(server.api),
        log,
      );
      final native = FakePaymentLauncher();
      final purchase = PurchaseController(
        repo,
        native,
        diagnostics: log,
        paymentChannel: 'ALIPAY',
      );
      addTearDown(purchase.dispose);
      await purchase.preview('BASIC', 1, agreementAccepted: true);
      await purchase.confirmPurchase('v1');
      expect(purchase.snapshot.order?.fulfillmentState, 'SUCCEEDED');
      expect(server.creates, 1);
      expect(server.materials, 1);
      expect(native.launches, 1);
    },
  );
}
