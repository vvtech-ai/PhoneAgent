import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_identity_surface_port.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_identity_surface_port.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/trusted_identity_surface');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const identity = TrustedIncomingIdentity(
    owner: TrustedCallerOwner('synthetic', '12345678901', 1),
    eventId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    caller: '10987654321',
    target: '12345678901',
    sequence: 'synthetic',
    verification: TrustedIdentityVerification.pending,
  );
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('non-iOS never sends a platform request', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'overlay';
    });
    final port = DeviceTrustedIdentitySurfacePort(
      environment: 'test',
      enabled: false,
    );
    expect(
      await port.synchronize(identity),
      TrustedIdentitySurfaceResult.fallback,
    );
    await port.dispose();
    expect(calls, isEmpty);
  });
  test(
    'native protocol sends safe snapshot, forwards events and clears on dispose',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'overlay';
      });
      final port = DeviceTrustedIdentitySurfacePort(
        environment: 'test',
        enabled: true,
      );
      expect(
        await port.synchronize(identity),
        TrustedIdentitySurfaceResult.overlay,
      );
      final payload = calls.single.arguments as Map;
      expect((payload['owner'] as Map)['environment'], 'test');
      expect(payload['presentationId'], identity.presentationId);
      expect(
        payload.keys,
        unorderedEquals([
          'owner',
          'eventId',
          'presentationId',
          'presentationRevision',
          'activityFresh',
          'identity',
        ]),
      );
      final event = port.events.first;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('dismissed', identity.presentationId),
        ),
        (_) {},
      );
      expect((await event).presentationId, identity.presentationId);
      await port.dispose();
      expect(calls.last.arguments, isNull);
    },
  );
  test(
    'unavailable plugin keeps ordinary path; native errors defer safely',
    () async {
      final port = DeviceTrustedIdentitySurfacePort(
        environment: 'test',
        enabled: true,
      );
      expect(
        await port.synchronize(identity),
        TrustedIdentitySurfaceResult.fallback,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(
        await port.synchronize(identity),
        TrustedIdentitySurfaceResult.deferred,
      );
      await port.dispose();
    },
  );
}
