import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/audio_playback_focus.dart';
import 'business_providers.dart';
import 'diagnostics_providers.dart';

/// Do not recreate on login change: old hardware may still be stopping.
final audioPlaybackFocusProvider = Provider<AudioPlaybackFocus>((ref) {
  final focus = AudioPlaybackFocus(
    diagnostics: () => ref.read(diagnosticJournalProvider).record,
  );
  void stop() => unawaited(focus.stopAll().catchError((Object _) {}));
  ref.listen(loginEpochProvider, (_, __) => stop());
  ref.onDispose(stop);
  return focus;
});
