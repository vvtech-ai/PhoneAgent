import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_agent/features/translation/data/recording/device_domestic_recording_encoder.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode ||
      !const bool.fromEnvironment('ENABLE_SYNTHETIC_RECORDING_PROBE')) {
    throw StateError('Synthetic recording probe must be explicitly enabled');
  }
  runApp(const MaterialApp(home: RecordingProbePage()));
}

class RecordingProbePage extends StatefulWidget {
  const RecordingProbePage({super.key});
  @override
  State<RecordingProbePage> createState() => _RecordingProbePageState();
}

class _RecordingProbePageState extends State<RecordingProbePage> {
  String status = '合成AAC编码验证中';
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    const encoder = DeviceDomesticRecordingEncoder();
    String? root;
    Map<String, Object?> report;
    Map<String, Object?>? inspected;
    try {
      root = await Directory(
        await encoder.privateRoot(),
      ).resolveSymbolicLinks();
      String hash(String value) =>
          sha256.convert(utf8.encode(value)).toString();
      final dir = await Directory(
        '$root/translation-recordings/${hash('synthetic-recording-probe-v1')}/${hash(DateTime.now().microsecondsSinceEpoch.toString())}',
      ).create(recursive: true);
      final pcm = ByteData(32000 * 2);
      for (var frame = 16000; frame < 32000; frame++) {
        pcm.setInt16(
          frame * 2,
          (sin(2 * pi * 440 * (frame - 16000) / 16000) * 11000).round(),
          Endian.little,
        );
      }
      final input = File('${dir.path}/mix.pcm16');
      final output = File('${dir.path}/recording.m4a');
      await input.writeAsBytes(pcm.buffer.asUint8List(), flush: true);
      await encoder.encode(pcmPath: input.path, m4aPath: output.path);
      final metrics = await const MethodChannel(
        'phone_agent/synthetic_recording_inspector',
      ).invokeMapMethod<String, Object?>('inspect', {'m4aPath': output.path});
      inspected = metrics;
      if (metrics == null ||
          metrics['sampleRate'] != 16000 ||
          metrics['channels'] != 1 ||
          metrics['codec'] != 'audio/mp4a-latm' ||
          metrics['durationSeconds'] is! num ||
          (metrics['durationSeconds'] as num) < 1.9 ||
          (metrics['durationSeconds'] as num) > 2.2 ||
          metrics['silenceRms'] is! num ||
          (metrics['silenceRms'] as num) > .01 ||
          metrics['toneRms'] is! num ||
          (metrics['toneRms'] as num) < .10) {
        throw StateError('Synthetic AAC metrics failed');
      }
      report = {
        'success': true,
        'fixture': '1s-silence+1s-440Hz-16k-mono',
        'inputBytes': await input.length(),
        'encodedBytes': await output.length(),
        'checksumSha256': sha256.convert(await output.readAsBytes()).toString(),
        'metrics': metrics,
      };
    } catch (failure) {
      report = {
        'success': false,
        'errorType': failure.runtimeType.toString(),
        if (failure is PlatformException) 'platformCode': failure.code,
        if (inspected != null) 'metrics': inspected,
      };
    }
    if (root != null) {
      await File(
        '$root/synthetic-probe-result.json',
      ).writeAsString(jsonEncode(report), flush: true);
    }
    debugPrint('SYNTHETIC_RECORDING_PROBE ${jsonEncode(report)}');
    if (mounted) {
      setState(
        () =>
            status = report['success'] == true ? '合成AAC编码验证通过' : '合成AAC编码验证失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Text('$status\n不录音、不联网、不接业务账号', textAlign: TextAlign.center),
      ),
    ),
  );
}
