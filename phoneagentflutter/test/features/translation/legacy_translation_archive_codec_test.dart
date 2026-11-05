import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/device_legacy_translation_archive.dart';
import 'package:phone_agent/features/translation/data/legacy_translation_archive_codec.dart';
import 'package:phone_agent/features/translation/data/translation_archive_codec.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import '../../support/legacy_translation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = DeviceLegacyTranslationArchive.channel;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'all recoverable v65 stages retain IDs times locator and transcripts',
    () {
      for (final stage in [
        'CONNECTED',
        'TERMINAL_DRAINING',
        'READY_TO_ARCHIVE',
        'ARCHIVING',
      ]) {
        final entry = LegacyTranslationArchiveCodec.decode(
          'a',
          jsonEncode([legacyTranslation(stage: stage)]),
        ).single;
        expect(entry.clientCallId, 'legacy-call');
        expect(entry.connectedAt, 1000);
        expect(entry.recover().endedAt, 1500);
        expect(
          entry.stage,
          stage == 'CONNECTED'
              ? TranslationArchiveStage.active
              : stage == 'TERMINAL_DRAINING'
              ? TranslationArchiveStage.draining
              : TranslationArchiveStage.ready,
        );
        expect(entry.locator!.grant, 'synthetic-grant');
        expect(entry.transcripts.single.source, '合成文字');
        final encoded = TranslationArchiveCodec.encode('s', 'a', [entry]);
        expect(encoded, isNot(contains('must-not-copy')));
        expect(encoded, isNot(contains('old-receipt')));
      }
    },
  );
  test('domestic, preconnect and already terminal records never replay', () {
    expect(
      LegacyTranslationArchiveCodec.decode(
        'a',
        jsonEncode([
          {'accountId': 'a', 'route': 'DOMESTIC_ANDROID'},
          for (final stage in ['PRE_CONNECT', 'COMPLETED', 'TERMINAL_FAILURE'])
            {'accountId': 'a', 'route': 'WORLD_CALL', 'stage': stage},
        ]),
      ),
      isEmpty,
    );
  });
  test(
    'corrupt or ambiguous records reject whole import with no sensitive error',
    () {
      final mutations = <void Function(Map<String, Object?>)>[
        (x) => x['accountId'] = 'other',
        (x) => x['route'] = 'UNKNOWN',
        (x) => x['stage'] = 'RECORDING_PENDING',
        (x) => x['connectedAtMs'] = null,
        (x) => x['endedAtMs'] = 999,
        (x) => x['lastObservedAtMs'] = 999,
        (x) => x['connectedAtMs'] = 1.5,
        (x) => x['endedAtMs'] = 8640000000000000,
        (x) => x['transcripts'] = null,
        (x) => (x['identity'] as Map)['clientCallId'] = '../bad',
        (x) =>
            ((x['identity'] as Map)['worldCallLocator']
                    as Map)['recordingAccessGrant'] =
                '',
      ];
      for (final mutate in mutations) {
        final raw = legacyTranslation();
        mutate(raw);
        expect(
          () => LegacyTranslationArchiveCodec.decode('a', jsonEncode([raw])),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'safe error',
              'Invalid legacy translation journal',
            ),
          ),
        );
      }
      for (final raw in [
        'null',
        '{}',
        '[',
        jsonEncode([legacyTranslation(), legacyTranslation()]),
        jsonEncode([
          {'accountId': 'other', 'route': 'DOMESTIC_ANDROID'},
        ]),
        ' ' * (8 * 1024 * 1024 + 1),
      ]) {
        expect(
          () => LegacyTranslationArchiveCodec.decode('a', raw),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'device bridge has exact account envelope and missing-source semantics',
    () async {
      Object? response;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        expect(call.arguments, {'accountId': 'a'});
        return response;
      });
      const source = DeviceLegacyTranslationArchive();
      expect(await source.read('a'), isNull);
      response = {'version': 1, 'accountId': 'a', 'pending': null};
      expect(await source.read('a'), isNull);
      response = {
        'version': 1,
        'accountId': 'a',
        'pending': jsonEncode([legacyTranslation()]),
      };
      expect((await source.read('a'))!.single.clientCallId, 'legacy-call');
      for (final bad in [
        {'version': 2, 'accountId': 'a', 'pending': null},
        {'version': 1, 'accountId': 'b', 'pending': null},
        {'version': 1, 'accountId': 'a'},
        {'version': 1, 'accountId': 'a', 'pending': 1},
      ]) {
        response = bad;
        await expectLater(source.read('a'), throwsFormatException);
      }
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await expectLater(source.read('a'), throwsA(isA<PlatformException>()));
    },
  );
}
