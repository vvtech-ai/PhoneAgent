import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/commerce/data/commerce_diagnostics.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'ios_purchase_fixture.dart';

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
  test(
    'Apple recovery keeps only approved business codes through persistence',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(
        store,
        flushDelay: const Duration(days: 1),
      );
      final log = CommerceDiagnostics(journal.record);
      log.event(
        CommerceStage.verify,
        DiagnosticResult.failed,
        error: const CommerceFailure('PAYMENT_VERIFICATION_FAILED'),
      );
      log.event(
        CommerceStage.verify,
        DiagnosticResult.failed,
        error: const CommerceFailure('private-arbitrary-code'),
      );
      await journal.flush();
      expect(store.value, isNot(contains('private-arbitrary-code')));
      journal.close();
      final restored = DiagnosticJournal(store);
      final events = (await restored.snapshot()).events;
      expect(
        events.first.commerce!.businessCode,
        'PAYMENT_VERIFICATION_FAILED',
      );
      expect(events.last.commerce!.businessCode, isEmpty);
      expect(
        DiagnosticCommerceDetails.fromJson({
          'stage': 'verify',
          'businessCode': 'private-token',
        }).businessCode,
        isEmpty,
      );
      restored.close();
    },
  );

  test(
    'iOS verification failures roundtrip with hashed recovery identity',
    () async {
      for (final stage in [
        'verificationUnverified',
        'verificationProductMismatch',
        'verificationTokenMissing',
        'verificationTokenMismatch',
        'verificationTypeUnsupported',
      ]) {
        final store = _Store();
        final journal = DiagnosticJournal(
          store,
          flushDelay: const Duration(days: 1),
        );
        final log = CommerceDiagnostics(journal.record);
        log.event(
          CommerceStage.nativePurchase,
          DiagnosticResult.failed,
          orderNo: 'private-order',
          error: PlatformException(
            code: 'CHANNEL_UNAVAILABLE',
            details: {
              'nativeStage': stage,
              'nativeCode': 0,
              'transactionId': 'private-returned-transaction',
              'platformProductId': 'private-returned-sku',
              'appAccountToken': 'private-token',
              'signedTransaction': 'private-jws',
            },
          ),
        );
        await journal.flush();
        expect(store.value, isNot(contains('private-')));
        journal.close();
        final restored = DiagnosticJournal(store);
        final details = (await restored.snapshot()).events.single.commerce!;
        expect(details.nativeStage, stage);
        expect(
          details.transactionRef,
          CommerceDiagnostics.reference('private-returned-transaction'),
        );
        expect(
          details.skuRef,
          CommerceDiagnostics.reference('private-returned-sku'),
        );
        expect(
          details.orderRef,
          CommerceDiagnostics.reference('private-order'),
        );
        expect(details.reason, CommerceReason.platform);
        restored.close();
      }
    },
  );
  test(
    'native metadata preserves explicit identity and ignores malformed IDs',
    () {
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      final error = PlatformException(
        code: 'CHANNEL_UNAVAILABLE',
        details: {
          'transactionId': 'native-transaction',
          'platformProductId': 'native-sku',
        },
      );
      log.event(
        CommerceStage.nativePurchase,
        DiagnosticResult.failed,
        transactionId: 'explicit-transaction',
        sku: 'explicit-sku',
        error: error,
      );
      expect(
        events.last.commerce!.transactionRef,
        CommerceDiagnostics.reference('explicit-transaction'),
      );
      expect(
        events.last.commerce!.skuRef,
        CommerceDiagnostics.reference('explicit-sku'),
      );
      log.event(
        CommerceStage.nativePurchase,
        DiagnosticResult.failed,
        error: PlatformException(
          code: 'CHANNEL_UNAVAILABLE',
          details: {
            'transactionId': 123,
            'platformProductId': {'private': 'value'},
            'nativeStage': 'verification-private-token',
          },
        ),
      );
      expect(events.last.commerce!.transactionRef, isEmpty);
      expect(events.last.commerce!.skuRef, isEmpty);
      expect(events.last.commerce!.nativeStage, isEmpty);
    },
  );

  test(
    'closed schema roundtrips journal without IDs, JWS, tokens or arbitrary error text',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(
        store,
        flushDelay: const Duration(days: 1),
      );
      final log = CommerceDiagnostics(journal.record);
      log.event(
        CommerceStage.nativePurchase,
        DiagnosticResult.failed,
        productId: 'private-product',
        sku: 'private-sku',
        quoteId: 'private-quote',
        orderNo: 'private-order',
        transactionId: 'private-transaction',
        state: 'private-user-text',
        price: 'private-price',
        currency: 'private-currency',
        error: PlatformException(
          code: 'private-code',
          message: 'private-jws-token',
          details: {
            'nativeDomain': 'SKErrorDomain',
            'nativeStage': 'products',
            'nativeCode': 3,
            'signedTransaction': 'private-jws',
            'appAccountToken': 'private-token',
            'parameters': 'private-parameters',
          },
        ),
      );
      await journal.flush();
      final json = store.value!;
      for (final raw in [
        'private-product',
        'private-sku',
        'private-quote',
        'private-order',
        'private-transaction',
        'private-user-text',
        'private-price',
        'private-currency',
        'private-code',
        'private-jws',
        'private-token',
        'private-parameters',
      ]) {
        expect(json, isNot(contains(raw)));
      }
      journal.close();
      final restored = DiagnosticJournal(store);
      final events = (await restored.snapshot()).events;
      expect(events.single.operation, DiagnosticOperation.commerceFlow);
      expect(events.single.commerce?.nativeDomain, 'SKErrorDomain');
      expect(events.single.commerce?.nativeCode, 3);
      expect(events.single.commerce?.nativeStage, 'products');
      expect(
        events.single.commerce?.orderRef,
        CommerceDiagnostics.reference('private-order'),
      );
      restored.close();
    },
  );
  test(
    'successful unchanged polling is deduplicated; fulfillment progress remains visible',
    () {
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      log.order(appleOrder());
      log.order(appleOrder());
      expect(
        events.where((e) => e.commerce?.stage == CommerceStage.orderState),
        hasLength(1),
      );
      expect(
        events.where((e) => e.commerce?.stage == CommerceStage.fulfillment),
        hasLength(1),
      );
      log.order(appleOrder(fulfillment: 'SUCCEEDED'));
      final states = events
          .where((e) => e.commerce?.stage == CommerceStage.orderState)
          .toList();
      expect(states, hasLength(2));
      expect(
        events.where((e) => e.commerce?.stage == CommerceStage.fulfillment),
        hasLength(2),
      );
      expect(events.first.commerce?.paymentState, 'SUCCEEDED');
      expect(events.first.commerce?.fulfillmentState, 'PROCESSING');
      expect(states.last.commerce?.state, 'completed');
      expect(events.last.commerce?.fulfillmentState, 'SUCCEEDED');
    },
  );
  test(
    'native pending/cancel are observational, never payment success',
    () async {
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      for (final outcome in NativePaymentOutcome.values) {
        await log.run(
          CommerceStage.nativePurchase,
          () async => NativePaymentResult(nativeOutcome: outcome),
        );
        expect(events.last.result, isNot(DiagnosticResult.succeeded));
        expect(events.last.commerce?.state, outcome.name);
      }
    },
  );
  test(
    'throwing diagnostics cannot change results or replace original errors',
    () async {
      final log = CommerceDiagnostics((_) => throw StateError('sink broken'));
      expect(await log.run(CommerceStage.quote, () async => 7), 7);
      final original = StateError('private original');
      await expectLater(
        log.run(CommerceStage.quote, () async => throw original),
        throwsA(same(original)),
      );
    },
  );
  test('unknown and extra persisted fields do not enter the closed schema', () {
    final details = DiagnosticCommerceDetails.fromJson({
      'stage': 'future',
      'state': 'private-token',
      'paymentState': 'private-text',
      'orderRef': 'raw-order',
      'nativeDomain': 'private-domain',
      'nativeStage': 'private-stage',
      'signedTransaction': 'private-jws',
      'appAccountToken': 'private-token',
    });
    expect(jsonEncode(details.toJson()), isNot(contains('private')));
    expect(details.stage, CommerceStage.unknown);
  });
}
