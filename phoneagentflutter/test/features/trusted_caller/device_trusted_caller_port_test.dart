import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_caller_port.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller_failure_message.dart';

const owner = TrustedCallerOwner('synthetic-account', 'synthetic-phone', 3);
const channel = MethodChannel('phone_agent/trusted_caller');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Map<String, Object?> reply(MethodCall call) => {
    ...Map<String, Object?>.from(call.arguments as Map),
    'linked': true,
    'configured': true,
    'needsIntroduction': true,
    'status': 'notAuthorized',
    'explicitSdkAuthorization': false,
  };
  DeviceTrustedCallerPort port({bool web = false}) => DeviceTrustedCallerPort(
    sdkEnvironment: 'test',
    platform: TargetPlatform.iOS,
    web: web,
  );
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'Android rejected capability is diagnosed as failure without opening',
    () async {
      for (final entry in [
        ('linked', 'SDK_RUNTIME_MISSING'),
        ('configured', 'SDK_NOT_CONFIGURED'),
      ]) {
        final events = <DiagnosticEvent>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {...reply(call), entry.$1: false};
        });
        final value = DeviceTrustedCallerPort(
          sdkEnvironment: 'test',
          platform: TargetPlatform.android,
          diagnostics: events.add,
        );
        await expectLater(
          value.prepare(owner),
          throwsA(
            isA<TrustedCallerFailure>().having((e) => e.code, 'code', entry.$2),
          ),
        );
        expect(events.last.result, DiagnosticResult.failed);
        expect(events.last.trustedCaller!.code, entry.$2);
        expect(calls.every((call) => call.method == 'prepare'), true);
      }
    },
  );
  test(
    'Android missing credentials remain actionable safe diagnostics',
    () async {
      final events = <DiagnosticEvent>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'SDK_CREDENTIALS_MISSING',
          message: 'synthetic-private',
        );
      });
      final value = DeviceTrustedCallerPort(
        sdkEnvironment: 'test',
        platform: TargetPlatform.android,
        diagnostics: events.add,
      );
      await expectLater(
        value.prepare(owner),
        throwsA(isA<TrustedCallerFailure>()),
      );
      expect(events.last.trustedCaller!.code, 'SDK_CREDENTIALS_MISSING');
      expect(
        events.last.toJson().toString(),
        isNot(contains('synthetic-private')),
      );
      expect(
        trustedCallerFailureMessage(
          const TrustedCallerFailure('SDK_CREDENTIALS_MISSING'),
          TrustedCallerOperation.prepare,
        ),
        '可信来电组件配置缺失，请更新安装包',
      );
    },
  );
  test(
    'iOS guide fact comes from prepare without authorization query',
    () async {
      final value = port();
      expect(await value.prepare(owner), true);
      expect(value.needsIntroduction, true);
      expect(calls.map((call) => call.method), ['prepare']);
    },
  );

  test(
    'iOS missing or malformed guide fact cannot skip introduction',
    () async {
      for (final guide in [null, 'true', 1]) {
        final value = port();
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => {...reply(call), 'needsIntroduction': guide},
        );
        if (guide == null) {
          expect(await value.prepare(owner), true);
          expect(
            () => value.needsIntroduction,
            throwsA(isA<TrustedCallerFailure>()),
          );
        } else {
          await expectLater(
            value.prepare(owner),
            throwsA(isA<TrustedCallerFailure>()),
          );
        }
      }
    },
  );

  test(
    'Android preparation needs no Flutter guide or authorization query',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {...reply(call)}..remove('needsIntroduction');
      });
      final value = DeviceTrustedCallerPort(
        sdkEnvironment: 'test',
        platform: TargetPlatform.android,
        web: false,
      );
      expect(await value.prepare(owner), true);
      expect(value.needsIntroduction, false);
      await value.openSettings(owner);
      expect(calls.map((call) => call.method), ['prepare', 'openSettings']);
    },
  );

  test('invalid owner never prepares either platform SDK', () async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final invalid in [
        const TrustedCallerOwner('account', 'phone', -1),
        ...[
          ...List.generate(32, (i) => i),
          ...List.generate(33, (i) => i + 127),
        ].map(
          (code) =>
              TrustedCallerOwner('a${String.fromCharCode(code)}b', 'phone', 0),
        ),
      ]) {
        final value = DeviceTrustedCallerPort(
          sdkEnvironment: 'test',
          platform: platform,
          web: false,
        );
        await expectLater(
          value.prepare(invalid),
          throwsA(
            isA<TrustedCallerFailure>().having(
              (error) => error.code,
              'code',
              'SDK_SURFACE_INVALID',
            ),
          ),
        );
      }
    }
    expect(calls, isEmpty);
  });

  test('complete owner and per-presentation token roundtrip', () async {
    final first = port(), second = port();
    expect(await first.prepare(owner), true);
    expect(await second.prepare(owner), true);
    expect(
      (calls[0].arguments as Map)['surfaceToken'],
      isNot((calls[1].arguments as Map)['surfaceToken']),
    );
    expect(
      (await first.readStatus(owner)).status,
      TrustedCallerStatus.notAuthorized,
    );
    await first.openSettings(owner);
    await first.releaseSurface(owner);
    await first.releaseSurface(owner);
    expect(
      calls.where((call) => call.method == 'releaseSurface'),
      hasLength(1),
    );
    expect(await second.prepare(owner), true);
  });

  test(
    'guide records require strict acknowledgement and preserve authorization',
    () async {
      final value = port();
      expect(await value.prepare(owner), true);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {...reply(call), 'needsIntroduction': true},
      );
      final before = await value.readStatus(owner);
      expect(before.needsIntroduction, true);
      expect(before.status, TrustedCallerStatus.notAuthorized);
      for (final acknowledgement in [true, 'false', null]) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => {
            ...reply(call),
            'needsIntroduction': acknowledgement,
          },
        );
        await expectLater(
          value.markIntroductionSeen(owner),
          throwsA(isA<TrustedCallerFailure>()),
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {...reply(call), 'needsIntroduction': false},
      );
      await value.markIntroductionSeen(owner);
      expect(
        (await value.readStatus(owner)).status,
        TrustedCallerStatus.notAuthorized,
      );
    },
  );

  test(
    'late guide acknowledgement is rejected after surface release',
    () async {
      final value = port();
      expect(await value.prepare(owner), true);
      final pending = Completer<Object?>();
      MethodCall? marker;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'markIntroductionSeen') {
          marker = call;
          return pending.future;
        }
        return null;
      });
      final marking = value.markIntroductionSeen(owner);
      final assertion = expectLater(
        marking,
        throwsA(isA<TrustedCallerFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      await value.releaseSurface(owner);
      pending.complete({...reply(marker!), 'needsIntroduction': false});
      await assertion;
    },
  );

  test('unconfigured SDK never reads or opens', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {...reply(call), 'configured': false},
    );
    final value = port();
    expect(await value.prepare(owner), false);
    await expectLater(
      value.readStatus(owner),
      throwsA(isA<TrustedCallerFailure>()),
    );
    await expectLater(
      value.openSettings(owner),
      throwsA(isA<TrustedCallerFailure>()),
    );
  });

  test('release invalidates an in-flight preparation', () async {
    final pending = Completer<Object?>();
    MethodCall? preparation;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepare') {
        preparation = call;
        return pending.future;
      }
      return null;
    });
    final value = port();
    final preparing = value.prepare(owner);
    final assertion = expectLater(
      preparing,
      throwsA(isA<TrustedCallerFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    await value.releaseSurface(owner);
    pending.complete(reply(preparation!));
    await assertion;
    expect(calls.map((call) => call.method), ['prepare', 'releaseSurface']);
  });

  test('foreign owner and token reports are rejected', () async {
    for (final field in [
      'surfaceToken',
      'accountId',
      'phone',
      'loginEpoch',
      'environment',
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {...reply(call), field: 'foreign'},
      );
      await expectLater(
        port().prepare(owner),
        throwsA(isA<TrustedCallerFailure>()),
      );
    }
  });

  test(
    'authorization requires exact status and explicit boolean proof',
    () async {
      final value = port();
      expect(await value.prepare(owner), true);
      for (final invalid in [
        {'status': 'authorized', 'explicitSdkAuthorization': false},
        {'status': 'authorized', 'explicitSdkAuthorization': 'true'},
        {'status': 'invented', 'explicitSdkAuthorization': true},
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => {...reply(call), ...invalid},
        );
        await expectLater(
          value.readStatus(owner),
          throwsA(isA<TrustedCallerFailure>()),
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          ...reply(call),
          'status': 'authorized',
          'explicitSdkAuthorization': true,
        },
      );
      expect((await value.readStatus(owner)).explicitSdkAuthorization, true);
    },
  );

  test('web and invalid owner never call native', () async {
    expect(await port(web: true).prepare(owner), false);
    await expectLater(
      port().prepare(const TrustedCallerOwner('', '', 0)),
      throwsA(isA<TrustedCallerFailure>()),
    );
    expect(calls, isEmpty);
  });

  test('changed account and released surface cannot be reused', () async {
    final value = port();
    await value.prepare(owner);
    await expectLater(
      value.prepare(const TrustedCallerOwner('other', 'phone', 4)),
      throwsA(isA<TrustedCallerFailure>()),
    );
    await value.releaseSurface(owner);
    await expectLater(
      value.prepare(owner),
      throwsA(isA<TrustedCallerFailure>()),
    );
  });
}
