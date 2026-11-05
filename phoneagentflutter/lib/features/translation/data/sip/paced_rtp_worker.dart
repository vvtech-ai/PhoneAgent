import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../../domain/sip/rtp_playout_queue.dart';
import '../../domain/sip/sip_rtp_packet.dart';
import '../../domain/sip/worker_pcm_uplink.dart';
import '../../domain/sip/sip_sdp.dart';
import 'dart:collection';

/// Owns the advertised UDP port and clock, independent of UI/model processing.
Future<void> pacedRtpWorker(List<Object> args) async {
  final parent = args[0] as SendPort;
  final commands = ReceivePort();
  RawDatagramSocket? socket;
  Timer? timer;
  StreamSubscription<RawSocketEvent>? receive;
  var closed = false, received = 0, gaps = 0, duplicates = 0;
  int? remoteSequence;
  final clock = Stopwatch()..start(), pacer = RtpDeadlinePacer();
  final queue = RtpPlayoutQueue(
    audioPayloadType: args[5] as int,
    silenceByte: args[6] as int,
  );
  var lastCommand = 0, lastStats = 0, maxInterval = 0;
  int? lastSent;
  WorkerPcmUplink? uplink;
  final direct = Queue<SipRtpPacket>();
  var sentFrames = 0, fillerFrames = 0, promptFrames = 0, directAudioFrames = 0;
  var promptAwaiting = false;
  Map<String, int> stats() => {
    'sentFrames': uplink == null ? queue.sent : sentFrames,
    'fillerFrames': uplink == null ? queue.fillers : fillerFrames,
    'underflows': uplink?.voiceUnderflows ?? queue.underflows,
    ...?uplink?.statistics,
    'maxQueuedFrames': queue.maxQueued,
    'maxPacingLagUs': pacer.maxLagMicros,
    'maxSendIntervalUs': maxInterval,
    'receivedPackets': received,
    'receiveGaps': gaps,
    'duplicates': duplicates,
    'promptFrames': promptFrames,
    'directAudioFrames': directAudioFrames,
    'rtpPayloadType': args[5] as int,
    'rtpCodec': args[6] == 0xd5 ? 1 : 0,
    'rtpClockRate': 8000,
    'rtpPacketSamples': 160,
  };
  Future<void> stop([String? failure]) async {
    if (closed) return;
    closed = true;
    timer?.cancel();
    socket?.close();
    commands.close();
    await receive?.cancel();
    parent.send(['stats', stats()]);
    if (failure != null) parent.send(['error', failure]);
    parent.send(['closed']);
  }

  try {
    final local = InternetAddress(args[1] as String);
    final peer = InternetAddress(args[3] as String), port = args[4] as int;
    socket = await RawDatagramSocket.bind(local, args[2] as int);
    socket.writeEventsEnabled = false;
    receive = socket.listen(
      (event) {
        if (event != RawSocketEvent.read || closed) return;
        for (var i = 0; i < 64; i++) {
          final datagram = socket!.receive();
          if (datagram == null) break;
          if (datagram.address != peer || datagram.port != port) continue;
          final packet = SipRtpPacket.parse(datagram.data);
          if (packet == null) continue;
          received++;
          if (remoteSequence != null) {
            final delta = (packet.sequence - remoteSequence!) & 0xffff;
            if (delta == 0 || delta > 0x7fff) {
              duplicates++;
              continue;
            }
            if (delta > 1) gaps += delta - 1;
          }
          remoteSequence = packet.sequence;
          parent.send(['packet', datagram.data]);
        }
      },
      onError: (Object _) {
        unawaited(stop('RTP_CONNECTION_LOST'));
      },
    );
    commands.listen((message) {
      if (closed || message is! List) return;
      lastCommand = clock.elapsedMilliseconds;
      if (message[0] == 'close') {
        unawaited(stop());
        return;
      }
      try {
        switch (message[0]) {
          case 'configure':
            uplink ??= WorkerPcmUplink(
              Map<String, num>.from(message[1] as Map),
              args[5] as int,
              args[6] == 0xd5 ? SipAudioCodec.pcma : SipAudioCodec.pcmu,
            );
          case 'pcm':
            uplink!.enqueue(
              message[1] as Uint8List,
              clock.elapsedMilliseconds,
              original: message[2] as bool,
            );
          case 'prompt':
            if (uplink == null || promptAwaiting) throw StateError('prompt');
            uplink!.enqueuePrompt(message[1] as Uint8List);
            promptAwaiting = true;
          case 'done':
            uplink!.finish(clock.elapsedMilliseconds);
          case 'events':
            for (final bytes in message[1] as List) {
              if (direct.length >= 100) throw StateError('capacity');
              direct.add(SipRtpPacket.parse(bytes as Uint8List)!);
            }
          case 'send':
            final packet = SipRtpPacket.parse(message[1] as Uint8List);
            if (packet == null) throw StateError('packet');
            if (uplink == null) {
              if (!queue.enqueue(packet)) throw StateError('capacity');
            } else {
              if (direct.length >= 100) throw StateError('capacity');
              direct.add(packet);
            }
        }
      } catch (_) {
        unawaited(stop('RTP_QUEUE_OVERFLOW'));
      }
    });
    void tick() {
      if (closed) return;
      final now = clock.elapsedMicroseconds;
      try {
        // A stalled owner cannot leave worker-generated audio running indefinitely.
        if ((queue.sent > 0 || sentFrames > 0) &&
            clock.elapsedMilliseconds - lastCommand > 2000) {
          unawaited(stop('RTP_OWNER_STALLED'));
          return;
        }
        final sender = uplink;
        final isDirect = direct.isNotEmpty;
        final packet = sender == null
            ? queue.next(clock.elapsedMilliseconds)
            : direct.isNotEmpty
            ? sender.stamp(direct.removeFirst())
            : sender.next(clock.elapsedMilliseconds);
        if (packet != null) {
          final bytes = packet.encode();
          if (socket!.send(bytes, peer, port) != bytes.length) {
            throw const SocketException('send');
          }
          if (lastSent != null && now - lastSent! > maxInterval) {
            maxInterval = now - lastSent!;
          }
          lastSent = now;
          if (sender != null) {
            sentFrames++;
            if (isDirect && packet.payloadType == args[5]) directAudioFrames++;
            if (!isDirect && sender.lastWasPrompt) {
              promptFrames++;
              if (promptAwaiting && !sender.promptPending) {
                promptAwaiting = false;
                parent.send(['promptDone']);
              }
            }
            if (sender.lastWasFiller &&
                !isDirect &&
                packet.payloadType == args[5]) {
              fillerFrames++;
            }
          }
        }
        pacer.sentAt(now);
        if (clock.elapsedMilliseconds - lastStats >= 5000) {
          lastStats = clock.elapsedMilliseconds;
          parent.send(['stats', stats()]);
        }
        timer = Timer(
          Duration(microseconds: pacer.delayMicros(clock.elapsedMicroseconds)),
          tick,
        );
      } catch (_) {
        unawaited(stop('RTP_SEND_FAILED'));
      }
    }

    parent.send(['ready', commands.sendPort]);
    tick();
  } catch (_) {
    await stop('RTP_BIND_FAILED');
  }
}
