import 'dart:typed_data';
import 'original_audio_mixer.dart';
import 'sip_pcm_frame_queue.dart';
import 'sip_pcm_uplink.dart';
import 'sip_rtp_transport.dart';

/// Uses whole PCM blocks for worker transports; legacy ports keep their clock.
class DomesticUplinkRoute {
  DomesticUplinkRoute({
    required this.transport,
    required bool mix,
    required double ratio,
    required double gain,
    required bool boost,
    required bool boundary,
    required int sequence,
    required int timestamp,
    required int ssrc,
  }) {
    final port = transport;
    if (port is SipPcmUplink) {
      _worker = port as SipPcmUplink;
      _worker!.configureUplink({
        'mix': mix ? 1 : 0,
        'ratio': ratio,
        'gain': gain,
        'boost': boost ? 1 : 0,
        'boundary': boundary ? 1 : 0,
        'sequence': sequence,
        'timestamp': timestamp,
        'ssrc': ssrc,
      });
    } else if (mix) {
      _mix = OriginalAudioMixer(
        ratio: ratio,
        pureGain: gain,
        dynamicBoost: boost,
        responseBoundarySupported: boundary,
      );
    }
  }
  final SipRtpTransport transport;
  SipPcmUplink? _worker;
  OriginalAudioMixer? _mix;
  final _queue = SipPcmFrameQueue();
  bool get workerOwned => _worker != null;

  Future<void> Function(List<Uint8List>)? get promptPlayer {
    final port = transport;
    if (port is! SipPromptUplink) return null;
    return (frames) {
      final pcm = BytesBuilder(copy: false);
      for (final frame in frames) {
        pcm.add(frame);
      }
      return (port as SipPromptUplink).playPrompt(pcm.takeBytes());
    };
  }

  void original(Uint8List pcm) {
    if (_worker != null) {
      _worker!.enqueuePcm(pcm, original: true);
    } else {
      _mix?.original(pcm);
    }
  }

  void translated(Uint8List pcm, int now) {
    if (_worker != null) {
      _worker!.enqueuePcm(pcm);
    } else if (_mix != null) {
      _mix!.translated(pcm, now);
    } else {
      _queue.enqueue(pcm);
    }
  }

  void done(int now) {
    if (_worker != null) {
      _worker!.finishPcm();
    } else if (_mix != null) {
      _mix!.responseDone(now);
    } else {
      _queue.markDone();
    }
  }

  Uint8List? next(int now) => workerOwned
      ? null
      : _mix != null
      ? _mix!.nextFrame(now)
      : _queue.nextFrame();
  void clear() {
    _mix?.clear();
    _queue.clear();
  }
}
