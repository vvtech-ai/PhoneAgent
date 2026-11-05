import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/device_call_recording_destination.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/call_recording_destination');
  const history = MethodChannel('phone_agent/history_recordings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DeviceCallRecordingDestination destination;
  final calls = <MethodCall>[];
  final historyCalls = <MethodCall>[];
  var selected = true;
  final asset = RecordingAudioAsset(
    '/synthetic/${'a' * 64}.m4a',
    'sample.m4a',
    'audio/wav',
    size: 8,
    sha256: 'b' * 64,
  );
  setUp(() {
    calls.clear();
    historyCalls.clear();
    selected = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'cancel' ? null : selected;
    });
    messenger.setMockMethodCallHandler(history, (call) async {
      historyCalls.add(call);
      return call.method == 'cancel' ? null : true;
    });
    destination = DeviceCallRecordingDestination(chooseFirst: true);
  });
  tearDown(() async {
    await destination.close();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(history, null);
  });
  test(
    'choose returns no URI; write is bound to same operation and local integrity',
    () async {
      expect(await destination.reserve('sample.m4a'), true);
      expect(calls.single.method, 'choose');
      final id = calls.single.arguments['id'];
      expect(id, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(await destination.write(asset), true);
      expect(calls.last.method, 'write');
      expect(calls.last.arguments, {
        'id': id,
        'path': asset.localPath,
        'size': 8,
        'sha256': asset.sha256,
      });
      await destination.close();
      expect(calls.map((e) => e.method), ['choose', 'write']);
    },
  );
  test('cancellation aborts only own ID; can reserve again', () async {
    selected = false;
    expect(await destination.reserve('sample.m4a'), false);
    final id = calls.single.arguments['id'];
    await destination.abort();
    expect(calls.last.arguments, {'id': id});
    selected = true;
    expect(await destination.reserve('sample.m4a'), true);
    expect(calls.last.arguments['id'], isNot(id));
  });
  test('remote and unverified assets cannot reach native writer', () async {
    await destination.reserve('sample.m4a');
    for (final invalid in [
      const RecordingAudioAsset('/file', 'sample', 'audio/wav'),
      RecordingAudioAsset.remote(
        Uri.parse('https://example.test/token'),
        'sample',
        'audio/wav',
      ),
    ]) {
      await expectLater(destination.write(invalid), throwsStateError);
    }
    expect(calls.map((e) => e.method), ['choose']);
  });
  test('iOS defers picker to existing local export port', () async {
    await destination.close();
    destination = DeviceCallRecordingDestination(chooseFirst: false);
    expect(await destination.reserve('sample.m4a'), true);
    expect(calls, isEmpty);
    expect(historyCalls, isEmpty);
    expect(await destination.write(asset), true);
    expect(historyCalls.single.method, 'save');
    expect(historyCalls.single.arguments['path'], asset.localPath);
  });
}
