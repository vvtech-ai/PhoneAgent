import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_caller_account_port.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/trusted_caller');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  const owner = TrustedCallerOwner('synthetic', 'synthetic-phone', 2);
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'both platforms reject invalid epoch and all control bytes locally',
    () async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        final port = DeviceTrustedCallerAccountPort(
          platform: platform,
          web: false,
        );
        expect(
          await port.updateAccount(
            const TrustedCallerOwner('a', 'b', -1),
            'test',
          ),
          false,
        );
        for (final code in [
          ...List.generate(32, (i) => i),
          ...List.generate(33, (i) => i + 127),
        ]) {
          final control = String.fromCharCode(code);
          for (final invalid in [
            TrustedCallerOwner('a${control}b', 'phone', 0),
            TrustedCallerOwner('account', 'p${control}h', 0),
          ]) {
            expect(await port.updateAccount(invalid, 'test'), false);
          }
        }
      }
      expect(calls, isEmpty);
      expect(
        const TrustedCallerOwner('合成账号', '+86 (synthetic)', 0).valid,
        true,
      );
    },
  );
  test(
    'iOS account transport sends owner only and explicitly signs out',
    () async {
      const port = DeviceTrustedCallerAccountPort(
        platform: TargetPlatform.iOS,
        web: false,
      );
      expect(await port.updateAccount(owner, 'test'), true);
      expect(calls.single.method, 'updateAccount');
      expect(calls.single.arguments, {
        'environment': 'test',
        'owner': {
          'accountId': 'synthetic',
          'phone': 'synthetic-phone',
          'loginEpoch': 2,
        },
      });
      expect(await port.updateAccount(null, 'test'), true);
      expect((calls.last.arguments as Map)['owner'], isNull);
    },
  );
  test(
    'unsupported platforms and malformed owner/config never call native',
    () async {
      for (final port in [
        const DeviceTrustedCallerAccountPort(
          platform: TargetPlatform.macOS,
          web: false,
        ),
        const DeviceTrustedCallerAccountPort(
          platform: TargetPlatform.iOS,
          web: true,
        ),
      ]) {
        expect(await port.updateAccount(owner, 'test'), false);
      }
      const port = DeviceTrustedCallerAccountPort(
        platform: TargetPlatform.iOS,
        web: false,
      );
      expect(await port.updateAccount(owner, 'invalid'), false);
      expect(
        await port.updateAccount(const TrustedCallerOwner('', '', 1), 'test'),
        false,
      );
      expect(calls, isEmpty);
    },
  );
  test(
    'Android delivers the full owner tuple and sign-out without permissions',
    () async {
      const port = DeviceTrustedCallerAccountPort(
        platform: TargetPlatform.android,
        web: false,
      );
      expect(await port.updateAccount(owner, 'test'), true);
      expect(calls.single.arguments, {
        'environment': 'test',
        'owner': {
          'accountId': 'synthetic',
          'phone': 'synthetic-phone',
          'loginEpoch': 2,
        },
      });
      expect(await port.updateAccount(null, 'test'), true);
      expect((calls.last.arguments as Map)['owner'], isNull);
      expect(calls.every((call) => call.method == 'updateAccount'), true);
    },
  );
  test(
    'missing plugin and safe native rejection are not registration success',
    () async {
      const port = DeviceTrustedCallerAccountPort(
        platform: TargetPlatform.iOS,
        web: false,
      );
      messenger.setMockMethodCallHandler(channel, null);
      expect(await port.updateAccount(owner, 'test'), false);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'SDK_ACCOUNT_INVALID'),
      );
      expect(
        () => port.updateAccount(owner, 'test'),
        throwsA(
          isA<TrustedCallerFailure>().having(
            (e) => e.code,
            'code',
            'SDK_ACCOUNT_INVALID',
          ),
        ),
      );
    },
  );
}
