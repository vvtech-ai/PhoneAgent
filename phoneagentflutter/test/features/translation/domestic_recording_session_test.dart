import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/domestic_recording_session.dart';
import 'package:phone_agent/features/translation/data/recording/private_domestic_recording_files.dart';
import 'package:phone_agent/features/translation/data/recording/pcm_recording_journal.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_encoder.dart';
import '../../support/recording_file_fixture.dart';

class SyntheticEncoder implements DomesticRecordingEncoder {
  int calls = 0;
  @override
  Future<void> encode({
    required String pcmPath,
    required String m4aPath,
  }) async {
    calls++;
    await File(m4aPath).writeAsBytes([1, 2, 3]);
  }
}

void main() {
  late Directory root;
  late RecordingFileFixture fixture;
  var current = true;
  setUp(() async {
    fixture = RecordingFileFixture();
    root = await fixture.directory('recording-owner');
    current = true;
  });
  tearDown(() => fixture.close());
  PrivateDomesticRecordingFiles files({String account = 'synthetic'}) =>
      PrivateDomesticRecordingFiles(
        environment: 'test',
        apiBase: 'https://example.invalid',
        accountId: account,
        root: () async => root,
        isCurrent: () => current,
      );
  test(
    'owner captures, finalizes once and resolves only its own account',
    () async {
      final encoder = SyntheticEncoder();
      final owned = files();
      final session = await DomesticRecordingSession.start(
        files: owned,
        clientCallId: 'call',
        encoder: encoder,
        nowNanos: () => 1000,
      );
      session.tap.localCapture(Uint8List(640), muted: false, intro: false);
      final a = session.finish(20), b = session.finish(20);
      expect(identical(a, b), isTrue);
      final result = await a;
      expect(result.durationMillis, 20);
      expect(encoder.calls, 1);
      expect(await (await owned.recording('call')).readAsBytes(), [1, 2, 3]);
      final recovered = await owned.recover('call');
      expect(recovered.originNanos, 1000);
      await expectLater(
        files(account: 'other').recording('call'),
        throwsA(anything),
      );
      current = false;
      await expectLater(owned.recording('call'), throwsStateError);
    },
  );
  test(
    'invalid recording tap cannot publish an apparently valid recording',
    () async {
      final encoder = SyntheticEncoder();
      final session = await DomesticRecordingSession.start(
        files: files(),
        clientCallId: 'call',
        encoder: encoder,
        nowNanos: () => 0,
      );
      session.tap.localCapture(Uint8List(1), muted: false, intro: false);
      await expectLater(session.finish(20), throwsStateError);
      expect(encoder.calls, 0);
    },
  );
  test(
    'directory redirect scope escape is refused before creating a capture',
    () async {
      final external = await fixture.directory('recording-outside');
      await fixture.directoryRedirect(
        '${root.path}/translation-recordings',
        external,
      );
      await expectLater(
        PcmRecordingJournal.create(
          privateRoot: root,
          environment: 'test',
          apiBase: 'https://example.invalid',
          accountId: 'synthetic',
          clientCallId: 'call',
          originNanos: 0,
        ),
        throwsFormatException,
      );
      expect(await external.list().isEmpty, isTrue);
    },
  );
}
