import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../translation_history/data/focused_recording_player.dart';
import '../../../translation_history/data/preview_recording_audio.dart';
import '../../../translation_history/presentation/controller/recording_audio_controller.dart';
import '../../../voice_clone/data/focused_clone_preview_player.dart';
import '../../data/preview_audio_focus_ports.dart';
import '../../data/preview_identity_focus_port.dart';
import '../../../voice_clone/data/focused_identity_capture_port.dart';

class AudioFocusPreviewController extends ChangeNotifier {
  AudioFocusPreviewController() {
    ordinary = _record(ordinaryPort);
    translation = _record(translationPort);
    clone = FocusedClonePreviewPlayer(
      PreviewFocusClone(),
      focus,
      isCurrent: () => !_closed,
    );
    _remove = [
      ordinary.addListener((value) {
        ordinaryState = value;
        _notify();
      }, fireImmediately: false),
      translation.addListener((value) {
        translationState = value;
        _notify();
      }, fireImmediately: false),
    ];
  }
  final focus = AudioPlaybackFocus();
  final ordinaryPort = PreviewFocusRecording(),
      translationPort = PreviewFocusRecording();
  late final RecordingAudioController ordinary, translation;
  late final FocusedClonePreviewPlayer clone;
  late final List<void Function()> _remove;
  bool _closed = false, clonePlaying = false;
  String message = '';
  PreviewIdentityFocusPort? _captureNative;
  FocusedIdentityCapturePort? _capture;
  bool capturing = false, cancellingCapture = false;
  String get captureStatus => !capturing
      ? '未采集'
      : cancellingCapture
      ? '等待 SDK 释放'
      : '采集占用中';
  RecordingAudioState ordinaryState = const RecordingAudioState();
  RecordingAudioState translationState = const RecordingAudioState();
  RecordingAudioController _record(PreviewFocusRecording port) =>
      RecordingAudioController(
        repository: PreviewRecordingRepository(RecordingPreviewScenario.normal),
        player: FocusedRecordingPlayer(port, focus, isCurrent: () => !_closed),
        exporter: PreviewRecordingExporter(
          () async => false,
          RecordingPreviewScenario.normal,
        ),
        isCurrent: () => !_closed,
      );
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() async {
    await Future.wait([ordinary.load(), translation.load()]);
    _notify();
  }

  void failPause(bool value) {
    ordinaryPort.failPause = value;
    _notify();
  }

  Future<void> previewClone() async {
    if (_closed || clonePlaying) return;
    clonePlaying = true;
    message = '';
    _notify();
    try {
      await clone.play(Uint8List(4));
    } catch (_) {
      message = '切换失败：旧音频尚未确认停止，未启动第二个播放';
    } finally {
      clonePlaying = false;
      _notify();
    }
  }

  Future<void> stopAll() async {
    try {
      await focus.stopAll();
      message = '所有合成播放已停止';
    } catch (_) {
      message = '停止失败，保留原占用；解除模拟失败后重试';
    }
    _notify();
  }

  Future<void> beginCapture() async {
    if (_closed || capturing) return;
    capturing = true;
    cancellingCapture = false;
    final native = _captureNative = PreviewIdentityFocusPort();
    final capture = _capture = FocusedIdentityCapturePort(
      native,
      focus,
      waitForRelease: native.waitForRelease,
      isCurrent: () => !_closed,
    );
    message = '';
    _notify();
    try {
      await capture.prepare();
      await capture.capture('mock-certify');
      message = '合成 SDK 已返回并释放；可重新试听';
    } catch (_) {
      message = '采集取消或失败；不继续认证/生成';
    } finally {
      capturing = false;
      _notify();
    }
  }

  Future<void> cancelCapture() async {
    if (!capturing || cancellingCapture) return;
    cancellingCapture = true;
    _notify();
    try {
      await _capture?.abort();
    } catch (_) {
      message = 'SDK 尚未确认释放';
    }
    _notify();
  }

  void finishCapture() => _captureNative?.finish();

  @override
  void dispose() {
    _closed = true;
    _captureNative?.finish();
    unawaited(_capture?.abort().catchError((Object _) {}));
    for (final remove in _remove) {
      remove();
    }
    ordinary.dispose();
    translation.dispose();
    unawaited(clone.close().catchError((Object _) {}));
    super.dispose();
  }
}
