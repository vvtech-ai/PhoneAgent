import 'dart:typed_data';
import 'original_audio_mixer.dart';
import 'sip_audio_codec.dart';
import 'sip_pcm_frame_queue.dart';
import 'sip_rtp_packet.dart';
import 'sip_sdp.dart';

/// Worker-owned PCM queue, mix and RTP clock. No UI frame timer is involved.
class WorkerPcmUplink {
  WorkerPcmUplink(Map<String, num> config, this.payloadType, this.codec)
    : _pcm = SipPcmFrameQueue(prebufferBytes: config['mix'] == 1 ? 640 : 5120),
      sequence = config['sequence']!.toInt(),
      timestamp = config['timestamp']!.toInt(),
      ssrc = config['ssrc']!.toInt(),
      _mix = config['mix'] == 1
          ? OriginalAudioMixer(
              ratio: config['ratio']!.toDouble(),
              pureGain: config['gain']!.toDouble(),
              dynamicBoost: config['boost'] == 1,
              responseBoundarySupported: config['boundary'] == 1,
            )
          : null;
  final int payloadType, ssrc;
  final SipAudioCodec codec;
  final OriginalAudioMixer? _mix;
  final SipPcmFrameQueue _pcm;
  final _prompt = SipPcmFrameQueue(prebufferBytes: 640);
  bool lastWasPrompt = false;
  bool get promptPending => _prompt.hasAudio;

  void enqueuePrompt(Uint8List pcm) {
    if (promptPending) throw StateError('Prompt already queued');
    _prompt.enqueue(pcm);
    _prompt.markDone();
  }

  int sequence, timestamp;
  int _eventDuration = 0, _lastInput = -1;
  bool _started = false,
      _voiceStarted = false,
      _complete = true,
      _starved = false;
  int voiceUnderflows = 0, idleFrames = 0, bufferingFrames = 0;
  int maxQueuedMs = 0, maxChunkGapMs = 0, inputChunks = 0;
  bool lastWasFiller = false;

  void enqueue(Uint8List pcm, int now, {bool original = false}) {
    if (original) {
      _mix?.original(pcm);
      return;
    }
    if (!_complete && _lastInput >= 0) {
      final gap = now - _lastInput;
      if (gap > maxChunkGapMs) maxChunkGapMs = gap;
    }
    _lastInput = now;
    inputChunks++;
    _complete = false;
    // Mirror the translated queue for independent backlog/underflow accounting.
    _pcm.enqueue(pcm);
    _mix?.translated(pcm, now);
    final queuedMs = _pcm.queuedBytes ~/ 32;
    if (queuedMs > maxQueuedMs) maxQueuedMs = queuedMs;
  }

  void finish(int now) {
    _complete = true;
    _pcm.markDone();
    _mix?.responseDone(now);
  }

  SipRtpPacket? next(int now) {
    lastWasPrompt = promptPending;
    if (lastWasPrompt) {
      lastWasFiller = false;
      return _encode(_prompt.nextFrame()!);
    }
    final before = _pcm.queuedBytes;
    final frame = _pcm.nextFrame();
    final consumed = _pcm.queuedBytes < before;
    lastWasFiller = !consumed;
    if (consumed) {
      _starved = false;
      _voiceStarted = true;
    } else if (_complete && before == 0) {
      idleFrames++;
      _starved = false;
      _voiceStarted = false;
    } else {
      bufferingFrames++;
      if (_voiceStarted && !_starved && before < 640) {
        voiceUnderflows++;
        _starved = true;
      }
    }
    final mixed = _mix?.nextFrame(now);
    final output = _mix == null ? frame : mixed;
    if (_mix != null) lastWasFiller = mixed == null;
    if (output == null && !_started) return null;
    _started = true;
    return _encode(output ?? Uint8List(640));
  }

  SipRtpPacket _encode(Uint8List output) {
    final pcm8k = SipAudioCodecConverter.resample(
      output,
      sourceRate: 16000,
      targetRate: 8000,
    );
    return stamp(
      SipRtpPacket(
        payloadType: payloadType,
        sequence: 0,
        timestamp: 0,
        ssrc: ssrc,
        payload: SipAudioCodecConverter.encode(codec, pcm8k),
      ),
    );
  }

  /// Telephone event packets retain one event timestamp and duration repeats.
  SipRtpPacket stamp(SipRtpPacket packet) {
    final audio = packet.payloadType == payloadType;
    if ((audio || packet.marker) && _eventDuration > 0) {
      timestamp = (timestamp + _eventDuration) & 0xffffffff;
      _eventDuration = 0;
    }
    final result = SipRtpPacket(
      payloadType: packet.payloadType,
      sequence: sequence,
      timestamp: timestamp,
      ssrc: ssrc,
      payload: packet.payload,
      marker: packet.marker,
    );
    sequence = (sequence + 1) & 0xffff;
    if (audio) {
      timestamp = (timestamp + packet.payload.length) & 0xffffffff;
      _started = true;
    } else if (packet.payload.length == 4) {
      _eventDuration = (packet.payload[2] << 8) | packet.payload[3];
    }
    return result;
  }

  Map<String, int> get statistics => {
    'voiceUnderflows': voiceUnderflows,
    'idleFrames': idleFrames,
    'bufferingFrames': bufferingFrames,
    'maxPcmQueuedMs': maxQueuedMs,
    'maxPcmChunkGapMs': maxChunkGapMs,
    'pcmInputChunks': inputChunks,
  };
}
