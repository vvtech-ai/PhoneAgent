import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/clone_preview_source_io.dart';
import 'package:phone_agent/features/voice_clone/data/plugin_clone_preview_player.dart';

void main() {
  test(
    'native preview owns a unique temporary WAV and removes only its directory',
    () async {
      final bytes = Uint8List.fromList([82, 73, 70, 70]);
      final first = await ClonePreviewSource.create(bytes);
      final second = await ClonePreviewSource.create(bytes);
      final firstFile = File((first.source as DeviceFileSource).path);
      final secondFile = File((second.source as DeviceFileSource).path);
      expect(firstFile.path, isNot(secondFile.path));
      expect(await firstFile.readAsBytes(), bytes);
      await first.close();
      await first.close();
      expect(await firstFile.parent.exists(), isFalse);
      expect(await secondFile.exists(), isTrue);
      await second.close();
      expect(await secondFile.parent.exists(), isFalse);
    },
  );
  test(
    'empty/oversized audio is rejected without touching a native plugin',
    () async {
      final player = PluginClonePreviewPlayer();
      await expectLater(player.play(Uint8List(0)), throwsStateError);
      await expectLater(
        player.play(Uint8List(10 * 1024 * 1024 + 1)),
        throwsStateError,
      );
      await player.close();
    },
  );
  test('closed player stays closed; stop and close are idempotent', () async {
    final player = PluginClonePreviewPlayer();
    await player.stop();
    await player.close();
    await player.close();
    await expectLater(player.play(Uint8List(1)), throwsStateError);
  });
}
