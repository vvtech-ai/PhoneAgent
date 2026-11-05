import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_incoming_identity_port.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = TrustedCallerOwner('synthetic', 'synthetic-phone', 1);
  Map<String, Object?> report() => {
    'owner': {
      'accountId': 'synthetic',
      'phone': 'synthetic-phone',
      'loginEpoch': 1,
      'environment': 'test',
    },
    'eventId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'activityFresh': false,
    'identity': {
      'verification': 'verified',
      'phoneno': '12025550100',
      'targetNumber': 'synthetic-phone',
      'sequence': 'synthetic',
    },
  };
  test(
    'owned event stream clears errors and never exposes raw payload',
    () async {
      final source = StreamController<Object?>();
      final port = DeviceTrustedIncomingIdentityPort(
        platform: TargetPlatform.iOS,
        web: false,
        events: source.stream,
      );
      final collected = port.watch(owner, 'test').toList();
      source.add(report());
      source.addError(
        PlatformException(
          code: 'SYNTHETIC_FAILURE',
          details: {'token': 'synthetic-private'},
        ),
      );
      await source.close();
      final values = await collected;
      expect(values.length, greaterThanOrEqualTo(2));
      expect(values.first?.hasCertificate, true);
      expect(values.last, isNull);
    },
  );
  test(
    'transient native error reconnects without replaying SDK commands',
    () async {
      var listens = 0;
      final ready = Completer<void>();
      final source = Stream<Object?>.multi((sink) {
        listens++;
        if (listens == 1) {
          sink.addError(PlatformException(code: 'synthetic'));
        } else {
          sink.add(report());
          ready.complete();
        }
      });
      final port = DeviceTrustedIncomingIdentityPort(
        platform: TargetPlatform.iOS,
        web: false,
        events: source,
        retryDelay: Duration.zero,
      );
      final values = <Object?>[];
      final subscription = port.watch(owner, 'test').listen(values.add);
      await ready.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(listens, 2);
      expect(values.first, isNull);
      expect(values.last, isNotNull);
      await subscription.cancel();
    },
  );
  test('diagnostic envelopes do not clear a displayed identity', () async {
    final source = StreamController<Object?>();
    final port = DeviceTrustedIncomingIdentityPort(
      platform: TargetPlatform.iOS,
      web: false,
      events: source.stream,
    );
    final values = <Object?>[];
    final subscription = port.watch(owner, 'test').listen(values.add);
    source.add(report());
    source.add({
      'diagnostic': {
        'stage': 'incomingReceive',
        'code': 'IOS_PUSH_FOREGROUND',
        'result': 'received',
        'timeMs': DateTime.now().millisecondsSinceEpoch,
      },
    });
    source.add({
      'diagnostic': {'code': 'invalid'},
    });
    await Future<void>.delayed(Duration.zero);
    expect(values, hasLength(1));
    expect(values.single, isNotNull);
    await subscription.cancel();
    await source.close();
  });
  test('repeated native errors stop after two reconnects', () async {
    var listens = 0;
    final source = Stream<Object?>.multi((sink) {
      listens++;
      sink.addError(PlatformException(code: 'synthetic'));
    });
    final port = DeviceTrustedIncomingIdentityPort(
      platform: TargetPlatform.iOS,
      web: false,
      events: source,
      retryDelay: Duration.zero,
    );
    expect(await port.watch(owner, 'test').toList(), [null, null, null]);
    expect(listens, 3);
  });
  test(
    'unsupported platform and invalid environment never subscribe',
    () async {
      var listeners = 0;
      final source = StreamController<Object?>.broadcast(
        onListen: () => listeners++,
      );
      for (final port in [
        DeviceTrustedIncomingIdentityPort(
          platform: TargetPlatform.android,
          web: false,
          events: source.stream,
        ),
        DeviceTrustedIncomingIdentityPort(
          platform: TargetPlatform.iOS,
          web: true,
          events: source.stream,
        ),
      ]) {
        expect(await port.watch(owner, 'test').toList(), isEmpty);
      }
      final port = DeviceTrustedIncomingIdentityPort(
        platform: TargetPlatform.iOS,
        web: false,
        events: source.stream,
      );
      expect(await port.watch(owner, 'invalid').toList(), isEmpty);
      expect(listeners, 0);
      await source.close();
    },
  );
  test('missing native availability refuses EventChannel activation', () async {
    const port = DeviceTrustedIncomingIdentityPort(
      platform: TargetPlatform.iOS,
      web: false,
    );
    expect(await port.watch(owner, 'test').toList(), [null]);
  });
  test('false native availability does not activate incoming stream', () async {
    const channel = MethodChannel('phone_agent/trusted_caller');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return false;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const port = DeviceTrustedIncomingIdentityPort(
      platform: TargetPlatform.iOS,
      web: false,
    );
    expect(await port.watch(owner, 'test').toList(), [null]);
    expect(calls.single.method, 'incomingEventsAvailable');
    expect(calls.single.arguments, {'environment': 'test'});
  });
  test(
    'owner replacement shares native stream so old cancel cannot close new listener',
    () async {
      const availability = MethodChannel('phone_agent/trusted_caller');
      const control = MethodChannel('phone_agent/trusted_caller_incoming');
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(availability, (_) async => true);
      messenger.setMockMethodCallHandler(control, (call) async {
        calls.add(call.method);
        if (call.method == 'listen' && !started.isCompleted) started.complete();
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(availability, null);
        messenger.setMockMethodCallHandler(control, null);
      });
      const port = DeviceTrustedIncomingIdentityPort(
        platform: TargetPlatform.iOS,
        web: false,
      );
      final firstEvents = <Object?>[], secondEvents = <Object?>[];
      final first = port.watch(owner, 'test').listen(firstEvents.add);
      await started.future.timeout(const Duration(seconds: 5));
      const nextOwner = TrustedCallerOwner('next', 'other-phone', 2);
      final second = port.watch(nextOwner, 'test').listen(secondEvents.add);
      await Future<void>.delayed(Duration.zero);
      final nextReport = report();
      nextReport['owner'] = {
        'accountId': 'next',
        'phone': 'other-phone',
        'loginEpoch': 2,
        'environment': 'test',
      };
      (nextReport['identity'] as Map)['targetNumber'] = 'other-phone';
      Future<void> emit() async {
        ServicesBinding.instance.channelBuffers.push(
          control.name,
          codec.encodeSuccessEnvelope(nextReport),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
      }

      await emit();
      expect(firstEvents.last, isNull);
      expect(secondEvents.last, isNotNull);
      await first.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['listen']);
      await emit();
      expect(secondEvents, hasLength(2));
      await second.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['listen', 'cancel']);
    },
  );
}
