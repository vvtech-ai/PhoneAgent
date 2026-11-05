import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import '../../support/cancellation_route_harness.dart';
import '../../support/cancellation_scenario.dart';
import '../../support/local_storage_channel_fake.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });
  testWidgets(
    'confirmed entry sends sms without accessing unavailable recovery storage',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final gateway = CancellationScenario()..failQuery = true;
        final store = CancellationRouteStore();
        await hostCancellationRoute(tester, store, gateway);
        var recoveryStorageCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
              if (call.method == 'installed') return true;
              final key = (call.arguments as Map?)?['key'];
              if (key is String && key.startsWith('cancellation.')) {
                recoveryStorageCalls++;
                throw PlatformException(code: 'synthetic-storage-unavailable');
              }
              return null;
            });
        await openCancellationEntry(tester);
        await confirmCancellationEntry(tester);
        await tester.pumpAndSettle();
        expect(gateway.confirmations, 1);
        expect(gateway.sends, 1);
        expect(gateway.queries, 0);
        expect(recoveryStorageCalls, 0);
        expect(store.clears, 0);
        expect(find.text('输入6位验证码'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'legacy recovery value cannot block entry or trigger an old lookup',
    (tester) async {
      final gateway = CancellationScenario()..failQuery = true;
      final store = CancellationRouteStore();
      final container = await hostCancellationRoute(tester, store, gateway);
      final config = container.read(appConfigProvider);
      final legacyKey =
          'cancellation.${config.environment?.name}.${config.sdkApiBaseUri ?? config.apiBaseUri}.synthetic-a';
      final legacyValue = jsonEncode({
        'challengeId': 'old-sms',
        'queryToken': 'expired-synthetic-query',
        'maskedPhone': '138****0000',
        'cooldown': 60,
        'operationId': 'old-operation',
        'storedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await const AppLocalStorage().write(key: legacyKey, value: legacyValue);
      await openCancellationEntry(tester);
      expect(gateway.queries, 0);
      await confirmCancellationEntry(tester);
      await tester.pumpAndSettle();
      expect(gateway.queries, 0);
      expect(gateway.confirmations, 1);
      expect(gateway.sends, 1);
      expect(gateway.submissions, 0);
      expect(store.clears, 0);
      expect(
        container.read(sessionControllerProvider).phase,
        SessionPhase.signedIn,
      );
      expect(find.text('输入6位验证码'), findsOneWidget);
      expect(await const AppLocalStorage().read(key: legacyKey), legacyValue);
    },
  );
  testWidgets(
    'accepted submission performs zero recovery storage operations and signs out',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final store = CancellationRouteStore();
        final gateway = CancellationScenario();
        final container = await hostCancellationRoute(tester, store, gateway);
        var recoveryStorageCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
              if (call.method == 'installed') return true;
              final key = (call.arguments as Map?)?['key'];
              if (key is String && key.startsWith('cancellation.')) {
                recoveryStorageCalls++;
                throw PlatformException(code: 'synthetic-storage-unavailable');
              }
              return null;
            });
        await openCancellationEntry(tester);
        await confirmCancellationEntry(tester);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('verification-code-input')),
          '123456',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-confirmation-submit')));
        await tester.pumpAndSettle();
        expect(gateway.queries, 0);
        expect(gateway.confirmations, 1);
        expect(gateway.sends, 1);
        expect(gateway.verifications, 1);
        expect(gateway.submissions, 1);
        expect(recoveryStorageCalls, 0);
        expect(store.clears, 1);
        expect(
          container.read(sessionControllerProvider).phase,
          SessionPhase.signedOut,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
