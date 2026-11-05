import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/data/device_recording_exporter.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/history_recordings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DeviceRecordingExporter exporter;
  final calls = <MethodCall>[];
  final asset = RecordingAudioAsset(
    '/private/synthetic.m4a',
    'sample.m4a',
    'audio/mp4',
    size: 5,
    sha256: List.filled(64, 'a').join(),
  );
  setUp(() {
    exporter = DeviceRecordingExporter();
    calls.clear();
  });
  tearDown(() async {
    await exporter.close();
    messenger.setMockMethodCallHandler(channel, null);
  });
  test('root and verified asset are passed only to native channel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'root' ? '/private/synthetic' : true;
    });
    expect(await exporter.cacheRoot(), '/private/synthetic');
    expect(await exporter.save(asset), true);
    expect(calls.last.arguments['sha256'], asset.sha256);
    expect(calls.last.arguments['size'], 5);
    expect(calls.last.arguments['id'], matches(RegExp(r'^[0-9a-f]{32}$')));
  });
  test('user cancellation is not success', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    expect(await exporter.save(asset), false);
  });
  test('unverified assets never enter system picker', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    await expectLater(
      exporter.save(const RecordingAudioAsset('x', 'x', 'audio/mp4')),
      throwsStateError,
    );
    expect(calls, isEmpty);
  });
  test('close cancels exact operation and suppresses late success', () async {
    final started = Completer<void>(), result = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'save') {
        started.complete();
        return result.future;
      }
      return null;
    });
    final pending = exporter.save(asset);
    await started.future;
    await exporter.close();
    expect(calls.last.method, 'cancel');
    expect(calls.last.arguments['id'], calls.first.arguments['id']);
    result.complete(true);
    expect(await pending, false);
    await expectLater(exporter.cacheRoot(), throwsStateError);
  });
  test('second save rejected while picker pending', () async {
    final started = Completer<void>(), result = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) async {
      started.complete();
      return result.future;
    });
    final pending = exporter.save(asset);
    await started.future;
    await expectLater(exporter.save(asset), throwsStateError);
    result.complete(false);
    expect(await pending, false);
  });
}
