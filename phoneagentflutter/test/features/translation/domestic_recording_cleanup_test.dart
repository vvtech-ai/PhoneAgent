import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/private_domestic_recording_files.dart';
import '../../support/recording_file_fixture.dart';

void main() {
  late Directory root;
  late RecordingFileFixture fixture;
  var current = true;
  late PrivateDomesticRecordingFiles files;
  setUp(() async {
    fixture = RecordingFileFixture();
    root = await fixture.directory('synthetic-cleanup');
    current = true;
    files = PrivateDomesticRecordingFiles(
      environment: 'test',
      apiBase: 'https://example.invalid',
      accountId: 'synthetic',
      root: () async => root,
      isCurrent: () => current,
    );
  });
  tearDown(() => fixture.close());
  test(
    'removes only confirmed call, preserves other calls and is idempotent',
    () async {
      final first = await files.create('call-1', 0);
      final other = await files.create('call-2', 0);
      final otherAccount = PrivateDomesticRecordingFiles(
        environment: 'test',
        apiBase: 'https://example.invalid',
        accountId: 'other-synthetic',
        root: () async => root,
        isCurrent: () => true,
      );
      final sameCall = await otherAccount.create('call-1', 0);
      await first.finish();
      await other.finish();
      await sameCall.finish();
      await File('${first.file.parent.path}/recording.m4a').writeAsBytes([1]);
      await files.removeArchived('call-1');
      expect(await first.file.parent.exists(), false);
      expect(await other.file.exists(), true);
      expect(await sameCall.file.exists(), true);
      await files.removeArchived('call-1');
    },
  );
  test(
    'unknown file causes rejection before any known file deletion',
    () async {
      final capture = await files.create('call-1', 0);
      await capture.finish();
      final extra = File('${capture.file.parent.path}/unknown');
      await extra.writeAsString('synthetic');
      await expectLater(files.removeArchived('call-1'), throwsFormatException);
      expect(await capture.file.exists(), true);
      expect(await extra.exists(), true);
    },
  );
  test('file symlink rejects without deleting target', () async {
    final capture = await files.create('call-1', 0);
    await capture.finish();
    final target = File('${root.path}/outside');
    await target.writeAsString('synthetic');
    final created = await fixture.fileSymlink(
      '${capture.file.parent.path}/recording.m4a',
      target,
    );
    if (!created) {
      markTestSkipped(
        'Windows file symlink errno1314: target-preservation assertions not covered',
      );
      return;
    }
    await expectLater(files.removeArchived('call-1'), throwsFormatException);
    expect(await target.readAsString(), 'synthetic');
    expect(await capture.file.exists(), true);
  });
  test(
    'changed account rejects cleanup without deleting any original file',
    () async {
      final capture = await files.create('call-1', 0);
      await capture.finish();
      final recording = File('${capture.file.parent.path}/recording.m4a');
      await recording.writeAsString('synthetic-recording');
      final originals = <String, List<int>>{};
      for (final entry in await capture.file.parent.list().toList()) {
        originals[entry.path] = await File(entry.path).readAsBytes();
      }
      current = false;
      await expectLater(files.removeArchived('call-1'), throwsStateError);
      for (final original in originals.entries) {
        expect(await File(original.key).readAsBytes(), original.value);
      }
    },
  );
  test(
    'directory redirect rejects before deletion and preserves external marker',
    () async {
      final capture = await files.create('call-1', 0);
      await capture.finish();
      final external = await fixture.directory('synthetic-cleanup-outside');
      final marker = File('${external.path}/marker');
      await marker.writeAsString('outside-marker');
      await fixture.directoryRedirect(
        '${capture.file.parent.path}/recording.m4a',
        external,
      );
      await expectLater(files.removeArchived('call-1'), throwsFormatException);
      expect(await marker.readAsString(), 'outside-marker');
      expect(await capture.file.exists(), true);
    },
  );
}
