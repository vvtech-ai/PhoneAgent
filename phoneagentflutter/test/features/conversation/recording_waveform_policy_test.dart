import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/device_call_recording_player.dart';
import 'package:phone_agent/features/conversation/domain/recording_waveform_policy.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  test(
    'real samples, silence, invalid sounding frames and recovery follow v66',
    () {
      final policy = RecordingWaveformPolicy();
      final quiet = List.filled(256, 128);
      expect(policy.bytes(quiet), everyElement(.12));
      final samples = List.generate(256, (i) => 128 + (i % 12) * 6);
      final real = policy.bytes(samples);
      expect(real.length, 24);
      expect(real.any((v) => v > .12), isTrue);
      final extremes = List.generate(256, (i) => i.isEven ? 0 : 255);
      final fallback = policy.bytes(extremes, rms: -1200);
      expect(fallback, everyElement(inInclusiveRange(.12, .68)));
      expect(policy.bytes(extremes, rms: -1200), isNot(fallback));
      final recovery = policy.bytes(List.generate(256, (i) => 128 + i % 47));
      expect(recovery, isNot(fallback));
      for (var i = 0; i < 4; i++) {
        policy.bytes(quiet, rms: -9600);
      }
      expect(policy.bytes(quiet), everyElement(.12));
      expect(policy.bytes([]), everyElement(.12));
    },
  );
  test(
    'unchanging or alternating invalid frames are limited and do not stop playback',
    () {
      final policy = RecordingWaveformPolicy();
      final a = List.generate(256, (i) => i.isEven ? 160 : 96);
      for (var i = 0; i < 9; i++) {
        policy.bytes(a);
      }
      final first = policy.bytes(a), second = policy.bytes(a);
      expect(second, isNot(first));
      expect(second, everyElement(inInclusiveRange(.12, .68)));
      expect(policy.levels(List.filled(24, double.nan)), everyElement(.12));
      expect(policy.levels(List.filled(24, 0)), everyElement(.12));
    },
  );
  test(
    'native player binds waves to its generation, resets on pause and ignores late output',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('synthetic-recording-player');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final commands = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        commands.add(call);
        return call.method == 'prepare' ? 12000 : null;
      });
      final native = StreamController<dynamic>.broadcast();
      final player = DeviceCallRecordingPlayer(
        channel: channel,
        nativeEvents: native.stream,
      );
      final received = <RecordingPlaybackEvent>[];
      final subscription = player.events.listen(received.add);
      const asset = RecordingAudioAsset(
        'synthetic.wav',
        'synthetic.wav',
        'audio/wav',
      );
      await player.prepare(asset);
      final identity = Map<String, Object?>.from(
        commands.last.arguments as Map,
      );
      await player.play();
      native.add({
        ...identity,
        'type': 'waveform',
        'bytes': List.filled(256, 160),
      });
      await Future<void>.delayed(Duration.zero);
      expect(received.last.waveform!.any((v) => v > .12), isTrue);
      await player.pause();
      await Future<void>.delayed(Duration.zero);
      expect(received.last.waveform, everyElement(.12));
      final count = received.length;
      native.add({
        ...identity,
        'type': 'waveform',
        'bytes': List.filled(256, 180),
      });
      await Future<void>.delayed(Duration.zero);
      expect(received.length, count);
      await player.prepare(asset);
      await player.play();
      native.add({...identity, 'type': 'completed'});
      await Future<void>.delayed(Duration.zero);
      expect(received.length, count);
      await player.close();
      await subscription.cancel();
      await native.close();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
