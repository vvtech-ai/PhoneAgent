import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/data/device_network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = 'phone_agent/network_availability_events';
  const control = MethodChannel(name);
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(control, (call) async {
      calls.add(call.method);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(control, null));
  Future<void> emit(Object? value) async {
    ServicesBinding.instance.channelBuffers.push(
      name,
      codec.encodeSuccessEnvelope(value),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'thin stream decodes OS evidence deduplicates and cancels native listener',
    () async {
      final received = <NetworkAvailability>[];
      final stream = const DeviceNetworkAvailability().watch().listen(
        received.add,
      );
      await Future<void>.delayed(Duration.zero);
      await emit('available');
      await emit('available');
      await emit('unavailable');
      await emit('untrusted');
      await emit('available');
      expect(received, [
        NetworkAvailability.available,
        NetworkAvailability.unavailable,
        NetworkAvailability.unknown,
        NetworkAvailability.available,
      ]);
      await stream.cancel();
      expect(calls, ['listen', 'cancel']);
      expect(received, hasLength(4));
    },
  );
  test(
    'platform stream error becomes unknown, not positive network evidence',
    () async {
      final received = <NetworkAvailability>[];
      final stream = const DeviceNetworkAvailability().watch().listen(
        received.add,
      );
      await Future<void>.delayed(Duration.zero);
      ServicesBinding.instance.channelBuffers.push(
        name,
        codec.encodeErrorEnvelope(code: 'unavailable', message: null),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, [NetworkAvailability.unknown]);
      await stream.cancel();
      expect(calls, ['listen', 'cancel']);
    },
  );

  test('two consumers share one native network listener', () async {
    const source = DeviceNetworkAvailability();
    final first = <NetworkAvailability>[];
    final second = <NetworkAvailability>[];
    final firstSubscription = source.watch().listen(first.add);
    final secondSubscription = source.watch().listen(second.add);
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['listen']);
    await emit('unavailable');
    await emit('available');
    expect(first, [
      NetworkAvailability.unavailable,
      NetworkAvailability.available,
    ]);
    expect(second, first);

    await firstSubscription.cancel();
    expect(calls, ['listen']);
    await secondSubscription.cancel();
    expect(calls, ['listen', 'cancel']);

    final resumed = <NetworkAvailability>[];
    final resumedSubscription = source.watch().listen(resumed.add);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['listen', 'cancel', 'listen']);
    await emit('unavailable');
    expect(resumed, [NetworkAvailability.unavailable]);
    await resumedSubscription.cancel();
    expect(calls, ['listen', 'cancel', 'listen', 'cancel']);
  });
}
