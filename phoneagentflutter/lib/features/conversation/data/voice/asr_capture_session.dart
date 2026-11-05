import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import '../../../../core/audio/pcm_capture.dart';
import '../../domain/voice/voice_gateway_event.dart';
import '../../domain/voice/voice_input_session.dart';
import 'asr_recognition_session.dart';

/// One physical hold + one ASR connection. Transcript submission stays outside.
/// Inject FocusedPcmCapture in production; synthetic tests need no microphone.
class AsrCaptureSession implements VoiceInputSession {
  AsrCaptureSession({
    required this.capture,
    required this.asr,
    this.captureBeforeReady = true,
  });
  final PcmCapture capture;
  final AsrRecognitionSession asr;
  final bool captureBeforeReady;
  final _preReady = ListQueue<Uint8List>();
  int _bufferedBytes = 0;
  bool _recognizerReady = false;
  static const _maximumPreReadyBytes = 64000; // Two seconds, PCM16 mono 16k.
  final _events = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  StreamSubscription<VoiceGatewayEvent>? _subscription;
  bool _used = false, _holding = false, _cancelled = false, _pumping = false;
  @override
  Stream<VoiceGatewayEvent> get events => _events.stream;

  @override
  Future<void> start(Uri endpoint) async {
    if (_used || _cancelled) throw StateError('Capture session already used');
    _used = true;
    _holding = true;
    _subscription = asr.events.listen(_onEvent);
    if (captureBeforeReady) {
      _pumping = true;
      unawaited(_pump());
    }
    await asr.start(endpoint);
  }

  void _emit(VoiceGatewayEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _onEvent(VoiceGatewayEvent event) {
    if (_cancelled) return;
    if (event is VoiceReady) {
      _recognizerReady = true;
      try {
        while (_holding && !_cancelled && _preReady.isNotEmpty) {
          final bytes = _preReady.removeFirst();
          _bufferedBytes -= bytes.length;
          _send(bytes);
        }
      } catch (error) {
        _captureFailure(error);
      }
      if (_holding && !_pumping) {
        _pumping = true;
        unawaited(_pump());
      }
    } else {
      _emit(event);
      if (event is VoiceGatewayFailure || event is VoiceTransportClosed) {
        _holding = false;
        _clearBuffer();
        unawaited(_stopAfterTransport());
      }
    }
  }

  Future<void> _pump() async {
    try {
      await capture.start();
      if (!_holding || _cancelled) return;
      // Unlike gateway ready, this proves native start has returned successfully.
      _emit(const VoiceReady());
      while (_holding && !_cancelled) {
        final bytes = await capture.read();
        if (!_holding || _cancelled) break;
        if (bytes == null) throw const PcmCaptureFailure('capture_interrupted');
        if (_recognizerReady) {
          _send(bytes);
        } else {
          if (bytes.isEmpty || bytes.length.isOdd || bytes.length > 640) {
            throw const PcmCaptureFailure('capture_invalid_pcm');
          }
          _preReady.add(Uint8List.fromList(bytes));
          _bufferedBytes += bytes.length;
          while (_bufferedBytes > _maximumPreReadyBytes) {
            _bufferedBytes -= _preReady.removeFirst().length;
          }
        }
      }
    } catch (error) {
      _captureFailure(error);
    }
  }

  void _send(Uint8List bytes) {
    if (!asr.sendPcm(bytes) && _holding && !_cancelled) {
      throw const PcmCaptureFailure('capture_send_failed');
    }
  }

  void _clearBuffer() {
    _preReady.clear();
    _bufferedBytes = 0;
  }

  void _captureFailure(Object error) {
    if (!_holding || _cancelled) return;
    _emit(
      VoiceGatewayFailure(
        error is PcmCaptureFailure ? error.code : 'capture_failed',
      ),
    );
    unawaited(
      cancel().catchError((Object _) {
        _emit(const VoiceGatewayFailure('capture_stop_failed'));
      }),
    );
  }

  /// Explicit hardware stop, not the user's release gesture/tail capture.
  @override
  Future<void> release() async {
    if (_cancelled) return;
    _holding = false;
    _clearBuffer();
    asr.release();
    await capture.stop();
  }

  Future<void> _stopAfterTransport() async {
    try {
      await capture.stop();
    } catch (_) {
      _emit(const VoiceGatewayFailure('capture_stop_failed'));
    }
  }

  /// Failed native stop remains retryable; never release ownership on a timer.
  @override
  Future<void> cancel() async {
    _cancelled = true;
    _holding = false;
    _clearBuffer();
    await Future.wait([asr.cancel(), capture.stop()]);
    // ASR already closed its event stream above; this listener has no native
    // cleanup. Do not introduce another asynchronous boundary after shutdown.
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _events.close();
  }
}
