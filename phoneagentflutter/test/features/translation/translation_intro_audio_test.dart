import 'package:dio/dio.dart';
import 'package:phone_agent/features/translation/data/sip/api_translation_intro_audio.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import '../../support/synthetic_account_api.dart';
import '../../support/translation_directory_fixture.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/asset_translation_intro_audio.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_intro_audio.dart';

void main() {
  test(
    'server prompt uses requested language endpoint and frozen directory',
    () async {
      final http = _WelcomeHttp();
      addTearDown(http.api.close);
      final dto = translationOptionsFixture();
      ((dto['languages'] as List).first as Map)['sourceWelcomeLanguageCode'] =
          'en';
      final source = ApiTranslationIntroAudio(
        http.api,
        directory: ApiTranslationDirectory.decode(dto),
      );
      final frames = await source.load('zh');
      expect(frames, isNotEmpty);
      expect(
        http.paths.single,
        '/api/v1/realtime-translation/welcome-prompts/zh/audio',
      );
      await source.load('zh');
      expect(http.paths, hasLength(1));
    },
  );
  test(
    'fixed native audio bytes, 24k conversion and 20ms frames stay intact',
    () async {
      final bundle = _Bundle();
      final source = AssetTranslationIntroAudio(bundle: bundle);
      const resources = {
        'zh': (
          '5667a569eac22402fde69206b60009ba5b642a7d6da2612c5bf1781db78c0731',
          200,
        ),
        'en': (
          '1c5058e7a69f297d96c1903d396468d3a30f3e82d1e48be8d5a2d15915054857',
          168,
        ),
        'ja': (
          '9658ac02649eccd5309be3b3e4e46abff5d79be54ae21ff7c6f4c85a1259353f',
          316,
        ),
        'trigger_zh': (
          'c15e3a5ba1b1b73310e2eb90630dc8e2fbdbc8ca7162a824ba5102f8bfbd0bb6',
          22,
        ),
      };
      for (final resource in resources.entries) {
        final bytes = await File(
          'assets/audio/translation_intro/translation_intro_${resource.key}.wav',
        ).readAsBytes();
        expect(sha256.convert(bytes).toString(), resource.value.$1);
        final frames = resource.key == 'trigger_zh'
            ? await source.trigger()
            : await source.load(resource.key);
        expect(frames.length, resource.value.$2);
        expect(frames.every((frame) => frame.length == 640), true);
      }
      expect(
        identical(await source.load('zh'), await source.load('zh-CN')),
        true,
      );
      expect(bundle.loads, 4);
      expect(identical(await source.load('fr'), await source.load('en')), true);
    },
  );
  test('long low-level pauses become silence, short pauses retain samples', () {
    final long = TranslationIntroAudio.frames(_wav(6400, 32));
    expect(long.every((frame) => frame.every((byte) => byte == 0)), true);
    final short = TranslationIntroAudio.frames(_wav(640, 32));
    expect(short.first[0], 32);
  });
  test(
    'malformed chunk, stereo and odd PCM are refused without decoding guesses',
    () {
      final valid = _wav(640, 1000);
      final stereo = Uint8List.fromList(valid);
      ByteData.sublistView(stereo).setUint16(22, 2, Endian.little);
      final odd = Uint8List.fromList(valid);
      ByteData.sublistView(odd).setUint32(40, 639, Endian.little);
      for (final value in [
        stereo,
        odd,
        Uint8List.sublistView(valid, 0, valid.length - 1),
      ]) {
        expect(() => TranslationIntroAudio.frames(value), throwsA(anything));
      }
    },
  );
}

Uint8List _wav(int size, int sample) {
  final bytes = Uint8List(44 + size);
  final data = ByteData.sublistView(bytes);
  void text(int at, String value) =>
      bytes.setRange(at, at + value.length, value.codeUnits);
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, size, Endian.little);
  for (var offset = 44; offset < bytes.length; offset += 2) {
    data.setInt16(offset, sample, Endian.little);
  }
  return bytes;
}

class _Bundle extends CachingAssetBundle {
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    loads++;
    return ByteData.sublistView(await File(key).readAsBytes());
  }
}

class _WelcomeHttp extends SyntheticAccountApi {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    paths.add(r.uri.path);
    expect(r.headers['Authorization'], 'Bearer synthetic');
    final bytes = await File(
      'assets/audio/translation_intro/translation_intro_zh.wav',
    ).readAsBytes();
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/wav'],
      },
    );
  }
}
