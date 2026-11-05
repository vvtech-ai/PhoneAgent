import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation_history/data/private_local_translation_recording.dart';
import 'domestic_recording_providers.dart';

final localTranslationRecordingProvider =
    Provider<PrivateLocalTranslationRecording?>((ref) {
      final files = ref.watch(domesticRecordingFilesProvider);
      if (files == null) return null;
      return PrivateLocalTranslationRecording(
        files,
        ref.watch(domesticRecordingEncoderProvider),
      );
    });
