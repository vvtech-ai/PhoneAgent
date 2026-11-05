import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/recording/translation_recording_tap.dart';
import 'package:phone_agent/features/translation/domain/recording/pcm_timeline.dart';

void main() {
  test(
    'mute and intro advance capture timeline without recording their sound',
    () {
      final times = <int>[], tracks = <TranslationRecordingTrack>[];
      var now = 1000000000;
      final tap = TranslationRecordingTap(
        nowNanos: () => now,
        sink: (track, time, pcm) {
          tracks.add(track);
          times.add(time);
          return true;
        },
      );
      final frame = Uint8List(640);
      tap.localCapture(frame, muted: false, intro: true);
      tap.localCapture(frame, muted: true, intro: false);
      now += 999999;
      tap.localCapture(frame, muted: false, intro: false);
      tap.peerFinalOutput(frame);
      expect(times, [1040000000, 1000999999]);
      expect(tracks, [
        TranslationRecordingTrack.localCaller,
        TranslationRecordingTrack.peerFinalOutput,
      ]);
    },
  );
  test(
    'disk rejection or exceptions invalidate recording without escaping to phone',
    () {
      var calls = 0;
      final tap = TranslationRecordingTap(
        nowNanos: () => 0,
        sink: (_, __, ___) {
          calls++;
          throw const FormatException('synthetic disk failure');
        },
      );
      tap.localCapture(Uint8List(640), muted: false, intro: false);
      tap.peerFinalOutput(Uint8List(640));
      expect(tap.available, isFalse);
      expect(calls, 1);
      final rejected = TranslationRecordingTap(
        nowNanos: () => 0,
        sink: (_, __, ___) => false,
      );
      rejected.peerFinalOutput(Uint8List(640));
      expect(rejected.available, isFalse);
    },
  );
}
