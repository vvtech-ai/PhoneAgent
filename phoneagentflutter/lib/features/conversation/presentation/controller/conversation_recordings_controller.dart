import 'dart:async';
import '../../domain/recording_playback_arbiter.dart';
import '../../../translation_history/presentation/controller/recording_audio_controller.dart';
import 'call_recording_playback_controller.dart';
import 'call_recording_metadata_observer.dart';
import 'call_recording_save_controller.dart';

class ConversationRecordingEntry {
  ConversationRecordingEntry({
    required this.playback,
    required this.metadata,
    required this.save,
  });
  final CallRecordingPlaybackController playback;
  final CallRecordingMetadataObserver metadata;
  final CallRecordingSaveController save;
  RecordingAudioController get audio => playback.audio;
  int visible = 0;
  void dispose() {
    metadata.close();
    save.dispose();
    playback.dispose();
  }
}

/// Route lifetime, not list-item lifetime. Visibility only controls metadata.
class ConversationRecordingsController {
  ConversationRecordingsController(
    this.create, {
    RecordingPlaybackArbiter? arbiter,
  }) : arbiter = arbiter ?? RecordingPlaybackArbiter();
  final ConversationRecordingEntry Function(String, RecordingPlaybackArbiter)
  create;
  final RecordingPlaybackArbiter arbiter;
  final _entries = <String, ConversationRecordingEntry>{};
  bool _foreground = true, _visible = true, _closed = false;

  ConversationRecordingEntry attach(String callId) {
    if (_closed) throw StateError('Recording host closed');
    final entry = _entries.putIfAbsent(callId, () => create(callId, arbiter));
    entry.visible++;
    if (_foreground && _visible) entry.metadata.start();
    return entry;
  }

  void detach(String callId, ConversationRecordingEntry entry) {
    if (_closed || !identical(_entries[callId], entry)) return;
    if (entry.visible > 0) entry.visible--;
    if (entry.visible == 0) entry.metadata.stop();
  }

  void setForeground(bool value) {
    _foreground = value;
    _sync();
  }

  void setVisible(bool value) {
    _visible = value;
    _sync();
  }

  void _sync() {
    if (_closed) return;
    if (!_foreground || !_visible) stopPlayback();
    for (final entry in _entries.values) {
      if (_foreground && _visible && entry.visible > 0) {
        entry.metadata.start();
      } else {
        entry.metadata.stop();
      }
    }
  }

  void stopPlayback() => unawaited(arbiter.stop().catchError((Object _) {}));
  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }
}
