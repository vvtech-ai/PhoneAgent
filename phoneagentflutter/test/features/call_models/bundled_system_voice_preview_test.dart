import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/data/bundled_system_voice_preview.dart';
import 'package:phone_agent/features/call_models/domain/system_voice_preview.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_preview_player.dart';

class _Player implements ClonePreviewPlayer {
  @override
  Future<void> play(Uint8List wav) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all five actual bundled native samples are RIFF WAV', () async {
    final port = BundledSystemVoicePreview(_Player());
    for (final id in systemVoicePreviewAssets.keys) {
      final bytes = await port.load(id);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(bytes.length, greaterThan(44));
    }
    await expectLater(port.load('unknown'), throwsStateError);
  });
  test(
    'private target reads requested current/candidate and never stock audio',
    () async {
      final calls = <bool>[];
      final port = BundledSystemVoicePreview(
        _Player(),
        loadClone: (current) async {
          calls.add(current);
          return Uint8List.fromList([7]);
        },
      );
      expect(await port.load(cloneCurrentPreviewId), [7]);
      expect(await port.load(cloneCandidatePreviewId), [7]);
      expect(calls, [true, false]);
      final unsupported = BundledSystemVoicePreview(_Player());
      await expectLater(
        unsupported.load(cloneCurrentPreviewId),
        throwsStateError,
      );
    },
  );
}
