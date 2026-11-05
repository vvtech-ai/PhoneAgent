import 'domestic_uplink_route.dart';
import 'sip_pcm_uplink.dart';
import 'domestic_local_playout.dart';
import 'dart:async';
import 'dart:typed_data';
import '../translation_pcm_bridge.dart';
import '../recording/translation_recording_tap.dart';
import '../translation_realtime_event.dart';
import 'domestic_translation_model.dart';
import 'domestic_translation_processor.dart';
import 'sip_audio_codec.dart';
import 'original_audio_mixer.dart';
import 'sip_lease.dart';
import 'sip_pcm_frame_queue.dart';
import 'sip_rtp_packet.dart';
import 'sip_rtp_transport.dart';
import 'sip_sdp.dart';
import 'domestic_translation_intro.dart';
import 'translation_intro_audio.dart';

/// Single-use duplex media owner. Permissions and audio focus belong to caller.
class DomesticSipMedia {
  DomesticSipMedia({
    required this.pcm,
    required this.models,
    required this.rtp,
    required this.endpoint,
    required this.isCurrent,
    required this.onFailure,
    required this.ssrc,
    this.sequence = 0,
    this.timestamp = 0,
    this.introSource,
    this.onDiagnostic,
    this.onStatistics,
    this.recordingTap,
    this.createRecordingTap,
    this.callerLanguage = 'zh',
    this.peerLanguage = 'en',
    this.introResponseBoundary = true,
    bool originalAudioEnabled = false,
    double originalRatio = .5,
    double originalVolume = 1,
    bool dynamicOriginalBoost = true,
    bool responseBoundarySupported = true,
  }) : _uplink = DomesticUplinkRoute(
         transport: rtp,
         mix: originalAudioEnabled,
         ratio: originalRatio,
         gain: originalVolume,
         boost: dynamicOriginalBoost,
         boundary: responseBoundarySupported,
         sequence: sequence,
         timestamp: timestamp,
         ssrc: ssrc,
       ),
       _remoteMix = originalAudioEnabled
           ? OriginalAudioMixer(
               ratio: originalRatio,
               pureGain: originalVolume,
               dynamicBoost: dynamicOriginalBoost,
               responseBoundarySupported: responseBoundarySupported,
             )
           : null;
  final void Function(String stage, String result, String code, Object? error)?
  onDiagnostic;
  final _seen = <String>{};
  void _trace(String stage, String result, [String code = '', Object? error]) {
    try {
      onDiagnostic?.call(stage, result, code, error);
    } catch (_) {
      /* isolated */
    }
  }

  void _first(String stage) {
    if (_seen.add(stage)) _trace(stage, 'succeeded');
  }

  final void Function(Map<String, int>)? onStatistics;
  DomesticLocalPlayout? _localPlayout;
  StreamSubscription<Map<String, int>>? _statisticsSubscription;
  void _statistics(Map<String, int> stats) {
    try {
      onStatistics?.call(stats);
    } catch (_) {
      /* isolated */
    }
  }

  final TranslationPcmBridge pcm;
  final DomesticTranslationProcessor models;
  final SipRtpTransport rtp;
  final SipAudioEndpoint endpoint;
  final bool Function() isCurrent;
  final void Function(String) onFailure;
  final int ssrc;
  final TranslationIntroAudioSource? introSource;
  TranslationRecordingTap? recordingTap;
  final Future<TranslationRecordingTap?> Function()? createRecordingTap;
  final String callerLanguage, peerLanguage;
  final bool introResponseBoundary;
  DomesticTranslationIntro? _intro;
  bool get acceptsModelOutput =>
      _active && !_closed && !(_intro?.suppressModelOutput ?? false);
  int sequence, timestamp;
  final OriginalAudioMixer? _remoteMix;
  final _clock = Stopwatch()..start();
  final DomesticUplinkRoute _uplink;
  final _downlink = SipPcmFrameQueue(prebufferBytes: 640);
  final _cancelled = Completer<void>();
  Future<void>? _startWork, _closeWork;
  Future<void>? _preparation;
  StreamSubscription<SipRtpPacket>? _subscription;
  Timer? _timer;
  bool _closed = false, _active = false, _muted = false;
  bool _pcmStarted = false, _speaker = true;
  bool _playing = false, _dtmf = false;
  bool cleanupUnconfirmed = false;
  int _playSequence = 0;
  int? _remoteSsrc, _remoteSequence;

  /// iOS only: initialize duplex hardware without starting business media.
  Future<void> prepare() => _preparation ??= _prepare();
  Future<void> _prepare() async {
    try {
      await models.start();
      _check();
      _trace('pcm', 'started');
      final bridge = pcm;
      if (bridge is! TranslationPcmPreparation) {
        throw const SipLeaseFailure('MEDIA_PREPARE_FAILED');
      }
      await (bridge as TranslationPcmPreparation).prepareCallAudio();
      _pcmStarted = true;
      _check();
      await pcm.setSpeaker(_speaker);
      _check();
      _trace('pcm', 'succeeded');
    } catch (error) {
      _trace('media', 'failed', 'MEDIA_PREPARE_FAILED', error);
      await close();
      throw const SipLeaseFailure('MEDIA_PREPARE_FAILED');
    }
  }

  Future<void> start() => _startWork ??= _start();
  Future<void> _start() async {
    try {
      if (_preparation != null) await _preparation;
      _check();
      if (createRecordingTap != null) {
        recordingTap = await createRecordingTap!();
        _check();
      }
      await models.start();
      _check();
      _trace('pcm', 'started');
      await pcm.start();
      _pcmStarted = true;
      _check();
      await pcm.setSpeaker(_speaker);
      _trace('pcm', 'succeeded');
      final transport = rtp;
      if (transport is SipRtpStatistics) {
        _statisticsSubscription = (transport as SipRtpStatistics).statistics
            .listen(_statistics);
      }
      if (_remoteMix == null) {
        _localPlayout = DomesticLocalPlayout(
          write: _play,
          onStatistics: _statistics,
          onFailure: (_) => _fail('MEDIA_PLAY_FAILED'),
        );
      }
      _check();
      _active = true;
      final source = introSource;
      if (source != null) {
        _intro = DomesticTranslationIntro(
          source: source,
          bufferedLocal: pcm is TranslationPcmDrain,
          queueRemote: _uplink.promptPlayer,
          callerLanguage: callerLanguage,
          peerLanguage: peerLanguage,
          responseBoundarySupported: introResponseBoundary,
          isCurrent: () => !_closed && isCurrent(),
          drainLocal: () async {
            final bridge = pcm;
            if (bridge is TranslationPcmDrain) {
              await (bridge as TranslationPcmDrain).drain();
            }
            _first('playFirst');
          },
          playLocal: (frame) =>
              pcm.play(TranslationAudio(frame, 16000, _playSequence++)),
          playRemote: (frame) async {
            _sendFrame(frame);
          },
          sendTrigger: (frame) =>
              models.sendAudio(DomesticTranslationLeg.local, frame),
        );
      }
      _trace('intro', 'started');
      final introWork = _intro?.start();
      _subscription = rtp.packets.listen(
        _receive,
        onError: (Object _) => _fail('RTP_CONNECTION_LOST'),
        onDone: () => _fail('RTP_CONNECTION_LOST'),
      );
      _timer = Timer.periodic(const Duration(milliseconds: 20), (_) => _tick());
      unawaited(_capture());
      await introWork;
      _trace('intro', 'succeeded');
      _check();
    } catch (error) {
      _trace(
        'media',
        'failed',
        error is SipLeaseFailure ? error.code : 'MEDIA_PREPARE_FAILED',
        error,
      );
      await close();
      if (error is SipLeaseFailure) {
        rethrow;
      }
      throw const SipLeaseFailure('MEDIA_PREPARE_FAILED');
    }
  }

  void _check() {
    if (_closed || !isCurrent()) {
      throw const SipLeaseFailure('MEDIA_CANCELLED');
    }
  }

  void setMuted(bool value) => _muted = value;
  Future<void> setSpeaker(bool enabled) async {
    _check();
    if (_pcmStarted) await pcm.setSpeaker(enabled);
    _check();
    _speaker = enabled;
  }

  Future<void> _capture() async {
    try {
      while (_active && !_closed) {
        final frame = await pcm.read();
        if (_closed) {
          return;
        }
        _check();
        if (frame == null) {
          throw const SipLeaseFailure('MEDIA_CAPTURE_ENDED');
        }
        if (frame.isEmpty) {
          continue;
        }
        _first('captureFirst');
        recordingTap?.localCapture(
          frame,
          muted: _muted,
          intro: _intro?.suppressLiveInput ?? false,
        );
        if (_intro?.suppressLiveInput ?? false) {
          continue;
        }
        final input = _muted ? Uint8List(frame.length) : frame;
        _uplink.original(input);
        models.sendAudio(DomesticTranslationLeg.local, input);
      }
    } catch (error) {
      if (_closed) return;
      _trace('captureFirst', 'failed', 'MEDIA_CAPTURE_FAILED', error);
      _fail('MEDIA_CAPTURE_FAILED');
    }
  }

  void _receive(SipRtpPacket packet) {
    if (!_active || _closed) {
      return;
    }
    if (!isCurrent()) {
      _fail('MEDIA_CANCELLED');
      return;
    }
    if (packet.payloadType != endpoint.payloadType ||
        packet.payload.isEmpty ||
        packet.payload.length > 1600) {
      return;
    }
    if (_remoteSsrc != null && packet.ssrc != _remoteSsrc) {
      return;
    }
    if (_remoteSequence != null) {
      final delta = (packet.sequence - _remoteSequence!) & 0xffff;
      if (delta == 0 || delta > 0x7fff) {
        return;
      }
    }
    if (_intro?.suppressLiveInput ?? false) {
      return;
    }
    _remoteSsrc = packet.ssrc;
    _remoteSequence = packet.sequence;
    try {
      _first('rtpFirst');
      final decoded = SipAudioCodecConverter.decode(
        endpoint.codec,
        packet.payload,
      );
      final frame = SipAudioCodecConverter.resample(
        decoded,
        sourceRate: 8000,
        targetRate: 16000,
      );
      _remoteMix?.original(frame);
      models.sendAudio(DomesticTranslationLeg.remote, frame);
    } catch (_) {
      _fail('MEDIA_DECODE_FAILED');
    }
  }

  /// Connect this to the processor's event callback before calling start.
  void onModelEvent(
    DomesticTranslationLeg direction,
    DomesticModelEvent event,
  ) {
    if (_closed) {
      return;
    }
    try {
      if (event is DomesticModelError) {
        _fail(event.code);
      } else if (event is DomesticModelResponseDone &&
          direction == DomesticTranslationLeg.local &&
          _intro != null) {
        _intro!.triggerResponseDone();
        if (!acceptsModelOutput) {
          return;
        }
        _uplink.done(_clock.elapsedMilliseconds);
      } else if (!acceptsModelOutput) {
        return;
      } else if (event is DomesticModelAudio) {
        if (direction == DomesticTranslationLeg.local) {
          _uplink.translated(event.pcm16k, _clock.elapsedMilliseconds);
        } else if (_remoteMix != null) {
          _remoteMix.translated(event.pcm16k, _clock.elapsedMilliseconds);
        } else if (_localPlayout != null) {
          _localPlayout!.enqueue(event.pcm16k);
        } else {
          _downlink.enqueue(event.pcm16k);
        }
      } else if (event is DomesticModelAudioDone ||
          event is DomesticModelResponseDone) {
        if (direction == DomesticTranslationLeg.local) {
          _uplink.done(_clock.elapsedMilliseconds);
        } else if (_remoteMix != null) {
          _remoteMix.responseDone(_clock.elapsedMilliseconds);
        } else {
          _downlink.markDone();
        }
      }
    } catch (_) {
      _fail('MEDIA_AUDIO_OVERFLOW');
    }
  }

  void _tick() {
    if (!_active || _closed) {
      return;
    }
    if (!isCurrent()) {
      _fail('MEDIA_CANCELLED');
      return;
    }
    if (_intro?.suppressLiveInput ?? false) {
      return;
    }
    try {
      if (!_dtmf) {
        final frame = _uplink.next(_clock.elapsedMilliseconds);
        if (frame != null) {
          _sendFrame(frame);
        }
      }
      if (!_playing && (_remoteMix != null || _downlink.hasAudio)) {
        final frame = _remoteMix == null
            ? _downlink.nextFrame()
            : _remoteMix.nextFrame(_clock.elapsedMilliseconds);
        if (frame != null) {
          unawaited(_play(frame));
        }
      }
    } catch (_) {
      _fail('MEDIA_SEND_FAILED');
    }
  }

  void _sendFrame(Uint8List frame) {
    _check();
    final pcm8k = SipAudioCodecConverter.resample(
      frame,
      sourceRate: 16000,
      targetRate: 8000,
    );
    rtp.send(
      SipRtpPacket(
        payloadType: endpoint.payloadType,
        sequence: sequence++,
        timestamp: timestamp,
        ssrc: ssrc,
        payload: SipAudioCodecConverter.encode(endpoint.codec, pcm8k),
      ),
    );
    timestamp = (timestamp + 160) & 0xffffffff;
    sequence &= 0xffff;
  }

  Future<void> _play(Uint8List frame) async {
    _playing = true;
    try {
      recordingTap?.peerFinalOutput(frame);
      await pcm.play(TranslationAudio(frame, 16000, _playSequence++));
    } catch (error) {
      _trace('playFirst', 'failed', 'MEDIA_PLAY_FAILED', error);
      _fail('MEDIA_PLAY_FAILED');
    } finally {
      _playing = false;
    }
  }

  Future<void> sendDtmf(
    String digit, {
    required Future<void> Function(String) sendInfo,
  }) async {
    _check();
    if (!_active ||
        _dtmf ||
        (_intro?.suppressLiveInput ?? false) ||
        !RegExp(r'^[0-9*#]$').hasMatch(digit)) {
      throw const SipLeaseFailure('INVALID_DTMF');
    }
    final payload = endpoint.telephoneEventPayload;
    _dtmf = true;
    try {
      if (payload == null) {
        await Future.any<void>([
          sendInfo(digit).timeout(const Duration(seconds: 3)),
          _cancelled.future,
        ]);
        _check();
        return;
      }
      final packets = SipTelephoneEvent.packets(
        digit: digit,
        payloadType: payload,
        sequence: sequence,
        timestamp: timestamp,
        ssrc: ssrc,
      );
      final port = rtp;
      if (port is SipPcmUplink) {
        (port as SipPcmUplink).sendTelephoneEvents(packets);
        await Future.any<void>([
          Future<void>.delayed(Duration(milliseconds: packets.length * 20)),
          _cancelled.future,
        ]);
        _check();
        return;
      }
      for (final packet in packets) {
        _check();
        rtp.send(packet);
        sequence = (packet.sequence + 1) & 0xffff;
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 20)),
          _cancelled.future,
        ]);
      }
      timestamp = (timestamp + 1280) & 0xffffffff;
    } finally {
      _dtmf = false;
    }
  }

  void _fail(String code) {
    if (_closed) {
      return;
    }
    unawaited(close());
    try {
      onFailure(code);
    } catch (_) {
      /* Resource disposal remains authoritative. */
    }
  }

  Future<void> close() {
    if (_closeWork != null) {
      return _closeWork!;
    }
    _closed = true;
    _active = false;
    _cancelled.complete();
    _timer?.cancel();
    _intro?.close();
    _localPlayout?.close();
    _clock.stop();
    _remoteMix?.clear();
    _uplink.clear();
    _downlink.clear();
    return _closeWork = _close();
  }

  Future<void> _close() async {
    await Future.wait([
      _dispose(models.close),
      _dispose(rtp.close),
      _dispose(pcm.close),
      _dispose(() async {
        await _subscription?.cancel();
      }),
    ]);
    await _statisticsSubscription?.cancel();
    cleanupUnconfirmed = cleanupUnconfirmed || models.cleanupUnconfirmed;
  }

  Future<void> _dispose(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      cleanupUnconfirmed = true;
    }
  }
}
