import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/tools/device_permission_channel.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/permissions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var response = 'denied';
  setUp(() {
    calls.clear();
    response = 'denied';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  testWidgets('settings waits for a real return to resumed before completing', (
    tester,
  ) async {
    const settings = MethodChannel('phone_agent/translation_location');
    final settingsCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(settings, (call) async {
      settingsCalls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(settings, null));
    const source = DevicePermissionChannel(
      web: false,
      platform: TargetPlatform.android,
    );
    var returned = false;
    final opened = source.openSettings().then((_) => returned = true);
    await tester.pump();
    expect(settingsCalls.single.method, 'openSettings');
    expect(returned, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(returned, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await opened;
    expect(returned, isTrue);
  });
  test('Web never sends a native request and never fakes grant', () async {
    const source = DevicePermissionChannel(
      web: true,
      platform: TargetPlatform.android,
    );
    expect(
      await source.resolve(ConversationPermission.contacts, request: true),
      PermissionGrant.unavailable,
    );
    expect(calls, isEmpty);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform passes only typed key and intent, validates response',
      () async {
        final source = DevicePermissionChannel(web: false, platform: platform);
        expect(
          await source.resolve(ConversationPermission.location, request: false),
          PermissionGrant.denied,
        );
        expect(calls.single.method, 'resolve');
        expect(calls.single.arguments, {
          'permission': 'location',
          'request': false,
        });
        response = 'granted';
        expect(
          await source.resolve(
            ConversationPermission.microphone,
            request: true,
          ),
          PermissionGrant.granted,
        );
        response = 'unexpected';
        await expectLater(
          source.resolve(ConversationPermission.contacts, request: true),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'permanent denial is decoded separately from a requestable denial',
    () async {
      const source = DevicePermissionChannel(
        web: false,
        platform: TargetPlatform.android,
      );
      response = 'blocked';
      expect(
        (await source.resolve(
          ConversationPermission.location,
          request: false,
        )).name,
        'blocked',
      );
    },
  );
  test(
    'document capability does not read files or request broad storage',
    () async {
      const source = DevicePermissionChannel(
        web: false,
        platform: TargetPlatform.android,
      );
      expect(
        await source.resolve(
          ConversationPermission.documentPicker,
          request: true,
        ),
        PermissionGrant.granted,
      );
      expect(calls, isEmpty);
    },
  );
}
