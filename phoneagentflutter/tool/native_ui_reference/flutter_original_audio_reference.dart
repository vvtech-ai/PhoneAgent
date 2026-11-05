import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/settings/presentation/pages/original_audio_page.dart';

/// Effective preference page with synthetic, process-local storage only.
class FlutterOriginalAudioReference extends StatefulWidget {
  const FlutterOriginalAudioReference({super.key});
  @override
  State<FlutterOriginalAudioReference> createState() =>
      _FlutterOriginalAudioReferenceState();
}

class _FlutterOriginalAudioReferenceState
    extends State<FlutterOriginalAudioReference> {
  final _store = _MemoryOriginalAudio();
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [originalAudioStoreProvider.overrideWithValue(_store)],
    child: const OriginalAudioPage(),
  );
}

class _MemoryOriginalAudio implements OriginalAudioStore {
  OriginalAudioSettings _value = const OriginalAudioSettings(enabled: true);
  @override
  Future<OriginalAudioSettings> read() async => _value;
  @override
  Future<void> write(OriginalAudioSettings value) async => _value = value;
}
