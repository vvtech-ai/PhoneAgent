import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../../core/audio/focused_pcm_capture.dart';
import '../../../../core/audio/pcm_playback_queue.dart';
import '../../../conversation/data/voice/asr_capture_session.dart';
import '../../../conversation/data/voice/task_asr_session.dart';
import '../../../conversation/data/voice/task_tts_session.dart';
import '../../../conversation/data/voice/task_tts_playback.dart';
import '../../../conversation/domain/voice/voice_gateway_event.dart';
import '../../data/preview_voice_socket.dart';
import '../../data/preview_pcm_capture.dart';
import '../../data/preview_pcm_output.dart';

class VoiceTransportPreviewController extends ChangeNotifier {
  AsrCaptureSession? _asr;
  PreviewPcmCapture? _capture;
  final _focus = AudioPlaybackFocus();
  TaskTtsSession? _tts;
  TaskTtsPlayback? _playback;
  PreviewPcmOutput? _output;
  int get pendingOutputBytes => _playback?.playback.queuedBytes ?? 0;
  bool get audioOccupied => _focus.active != null;
  String get outputStatus => switch (_playback?.playback.phase) {
    null => '未播放',
    PcmPlaybackPhase.accepting => '接收音频',
    PcmPlaybackPhase.draining => '等待设备播完',
    PcmPlaybackPhase.drained => '已播完并释放',
    PcmPlaybackPhase.cancelled => '已取消',
    PcmPlaybackPhase.failed => '播放失败',
  };
  void consumeOutput() => _output?.consume();
  void failOutput() => _output?.fail();
  Future<void> stopOutput() async {
    await _playback?.cancel();
    _notify();
  }

  PreviewVoiceSocket? asrSocket, ttsSocket;
  bool _closed = false;
  int _asrIntent = 0, _ttsIntent = 0;
  String asrStatus = '未连接', text = '', ttsStatus = '未合成';
  final List<int> chunks = [];
  bool pcmAccepted = false;
  final _subscriptions = <StreamSubscription<VoiceGatewayEvent>>[];
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> startAsr() async {
    final intent = ++_asrIntent;
    await _asr?.cancel();
    if (_closed || intent != _asrIntent) return;
    final socket = asrSocket = PreviewVoiceSocket();
    final capture = _capture = PreviewPcmCapture();
    final session = _asr = AsrCaptureSession(
      capture: FocusedPcmCapture(
        capture,
        _focus,
        isCurrent: () => !_closed && intent == _asrIntent,
      ),
      asr: TaskAsrSession(connector: (_) async => socket),
    );
    text = '';
    pcmAccepted = false;
    asrStatus = '等待 ready';
    _subscriptions.add(
      session.events.listen((event) {
        if (_closed || !identical(_asr, session)) return;
        if (event is VoiceReady) asrStatus = '合成采集已启动，可发送 PCM';
        if (event is VoiceTranscript) text = event.text;
        if (event is VoiceGatewayFailure) asrStatus = '失败：${event.message}';
        if (event is VoiceTransportClosed) asrStatus = '已关闭：${event.reason}';
        _notify();
      }),
    );
    await session.start(Uri.parse('ws://synthetic.invalid/asr'));
    _notify();
  }

  void ready() => asrSocket?.emit('{"type":"ready"}');
  Future<void> sendPcm() async {
    pcmAccepted = _capture?.emitFrame() ?? false;
    await Future<void>.delayed(Duration.zero);
    _notify();
  }

  Future<void> release() async {
    await _asr?.release();
    if (_asr != null) asrStatus = '已松手，等待一次 final';
    _notify();
  }

  void finalText() => asrSocket?.emit('{"type":"final","text":"合成最终文本"}');
  Future<void> cancel() async {
    ++_asrIntent;
    await _asr?.cancel();
    asrStatus = '已取消，采集已释放';
    _notify();
  }

  Future<void> synthesize() async {
    final intent = ++_ttsIntent;
    await _playback?.cancel();
    if (_closed || intent != _ttsIntent) return;
    final socket = ttsSocket = PreviewVoiceSocket();
    final session = _tts = TaskTtsSession(connector: (_) async => socket);
    final playback = _playback = TaskTtsPlayback(
      tts: session,
      output: _output = PreviewPcmOutput(),
      focus: _focus,
      isCurrent: () => !_closed && intent == _ttsIntent,
      onChanged: _notify,
    );
    chunks.clear();
    ttsStatus = '等待 ready';
    _subscriptions.add(
      session.events.listen((event) {
        if (_closed || !identical(_tts, session)) return;
        if (event is VoicePcmChunk) chunks.add(event.bytes.length);
        if (event is VoiceSynthesisComplete) ttsStatus = '合成完成，不代表播放排空';
        if (event is VoiceGatewayFailure) ttsStatus = '失败：${event.message}';
        _notify();
      }),
    );
    await playback.start(
      Uri.parse('ws://synthetic.invalid/tts'),
      text: '合成演练',
      speaker: 'mock',
    );
    socket.emit('{"type":"ready"}');
    _notify();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_asr?.cancel());
    unawaited(_playback?.cancel());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
