import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:phone_agent/features/translation/data/sip/paced_sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_audio_codec.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_intro_audio.dart';

/// Public bundled prompts only. Never loads account configuration or user audio.
Future<void> main() async {
  final output = Directory('.local/audio-uplink-audit');
  final ignored = await Process.run('git', [
    'check-ignore',
    '--quiet',
    output.path,
  ]);
  if (ignored.exitCode != 0 ||
      FileSystemEntity.isLinkSync('.local') ||
      FileSystemEntity.isLinkSync(output.path)) {
    throw StateError('Audit output must be ignored and not redirected');
  }
  await output.create(recursive: true);
  final reports = <Map<String, Object>>[];
  for (final language in ['zh', 'en', 'ja']) {
    final wav = await File(
      'assets/audio/translation_intro/translation_intro_$language.wav',
    ).readAsBytes();
    final frames = TranslationIntroAudio.frames(wav);
    final pcm = BytesBuilder(copy: false), pcm8k = BytesBuilder(copy: false);
    for (final frame in frames) {
      pcm.add(frame);
      pcm8k.add(
        SipAudioCodecConverter.resample(
          frame,
          sourceRate: 16000,
          targetRate: 8000,
        ),
      );
    }
    final source = pcm.takeBytes(), referencePcm = pcm8k.takeBytes();
    await File('${output.path}/$language.pcm8k').writeAsBytes(referencePcm);
    for (final codec in SipAudioCodec.values) {
      reports.add(await audit(output, language, codec, source, frames.length));
    }
  }
  await File(
    '${output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(reports));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(reports));
}

Future<Map<String, Object>> audit(
  Directory output,
  String language,
  SipAudioCodec codec,
  Uint8List pcm,
  int expectedFrames,
) async {
  final local = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final peer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final pt = codec == SipAudioCodec.pcma ? 8 : 0;
  final transport = await PacedSipRtpTransport.open(
    socket: local,
    peer: InternetAddress.loopbackIPv4,
    peerPort: peer.port,
    payloadType: pt,
    silenceByte: pt == 8 ? 0xd5 : 0xff,
  );
  final packets = <SipRtpPacket>[], stats = <Map<String, int>>[];
  final first = Completer<void>(), complete = Completer<void>();
  final sub = peer.listen((event) {
    if (event != RawSocketEvent.read) return;
    Datagram? datagram;
    while ((datagram = peer.receive()) != null) {
      final packet = SipRtpPacket.parse(datagram!.data);
      if (packet == null) {
        if (!complete.isCompleted) {
          complete.completeError(StateError('Invalid RTP'));
        }
        continue;
      }
      packets.add(packet);
      if (!first.isCompleted) first.complete();
      if (packets.length >= expectedFrames && !complete.isCompleted) {
        complete.complete();
      }
    }
  });
  final statSub = transport.statistics.listen(stats.add);
  try {
    transport.configureUplink({
      'sequence': 65534,
      'timestamp': 0xffffff00,
      'ssrc': 42,
      'mix': 0,
      'ratio': .5,
      'gain': 1,
      'boost': 1,
      'boundary': 1,
    });
    transport.enqueuePcm(pcm);
    transport.finishPcm();
    await first.future.timeout(const Duration(seconds: 2));
    // A prequeued worker must keep sending even when the UI owner is blocked.
    sleep(const Duration(milliseconds: 240));
    await complete.future.timeout(
      Duration(milliseconds: expectedFrames * 20 + 2000),
    );
    await transport.close();
    final payload = BytesBuilder(copy: false);
    for (var i = 0; i < expectedFrames; i++) {
      final packet = packets[i];
      if (packet.payloadType != pt ||
          packet.ssrc != 42 ||
          packet.payload.length != 160 ||
          packet.sequence != ((65534 + i) & 0xffff) ||
          packet.timestamp != ((0xffffff00 + i * 160) & 0xffffffff)) {
        throw StateError('RTP header, continuity or frame length mismatch');
      }
      payload.add(packet.payload);
    }
    await File(
      '${output.path}/$language-${codec.name}.g711',
    ).writeAsBytes(payload.takeBytes());
    return {
      'language': language,
      'codec': codec.name,
      'frames': expectedFrames,
      'audioMs': expectedFrames * 20,
      'ownerBlockMs': 240,
      'continuity': true,
      'statistics': stats.isEmpty ? {} : stats.last,
    };
  } finally {
    await transport.close();
    await statSub.cancel();
    await sub.cancel();
    peer.close();
  }
}
