import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/dialer/data/device_legacy_call_records.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'legacy_app_call_record_codec_test.dart' show legacyRecordFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/legacy_call_records');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var calls = 0;
  Object? response;
  Object? failure;
  DeviceLegacyCallRecords source({
    String env = 'prod',
    String host = 'chaken.ai',
    TargetPlatform platform = TargetPlatform.android,
    bool web = false,
    String account = 'phone-synthetic',
  }) => DeviceLegacyCallRecords(
    config: AppConfig.parse(
      environment: env,
      apiBaseUrl: 'https://$host/aiassistant-api/',
    ),
    accountId: account,
    platform: platform,
    web: web,
  );
  setUp(() {
    calls = 0;
    failure = null;
    response = {
      'version': 1,
      'accountId': 'phone-synthetic',
      'records': jsonEncode([legacyRecordFixture()]),
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'read');
      expect(call.arguments, {'accountId': 'phone-synthetic'});
      if (failure != null) throw failure!;
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('only fixed account argument crosses native channel', () async {
    expect((await source().read()).single.id, 'synthetic-call');
    expect(calls, 1);
  });
  test('non-production and non-Android sources never invoke channel', () async {
    for (final value in [
      source(env: 'dev'),
      source(host: 'other.invalid'),
      source(platform: TargetPlatform.iOS),
      source(web: true),
    ]) {
      expect(await value.read(), isEmpty);
    }
    expect(calls, 0);
  });
  test(
    'guest, blank and arbitrary path accounts fail before native read',
    () async {
      for (final account in [
        '',
        'guest',
        '../other',
        'name/other',
        'x' * 257,
      ]) {
        await expectLater(
          source(account: account).read(),
          throwsA(isA<AppCallRecordFailure>()),
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'null native response is absent; wrong account and version are rejected',
    () async {
      response = null;
      expect(await source().read(), isEmpty);
      for (final value in [
        {'version': 1, 'accountId': 'other', 'records': '[]'},
        {'version': 2, 'accountId': 'phone-synthetic', 'records': '[]'},
        {'version': 1, 'accountId': 'phone-synthetic', 'records': []},
        {'version': 1, 'accountId': 'phone-synthetic'},
      ]) {
        response = value;
        await expectLater(
          source().read(),
          throwsA(isA<AppCallRecordFailure>()),
        );
      }
    },
  );
  test(
    'platform failure is sanitized and not mistaken for empty source',
    () async {
      failure = PlatformException(
        code: 'unavailable',
        message: 'synthetic-private',
      );
      await expectLater(
        source().read(),
        throwsA(
          predicate(
            (e) =>
                e is AppCallRecordFailure &&
                e.code == 'legacy-unavailable' &&
                !'$e'.contains('private'),
          ),
        ),
      );
    },
  );
}
