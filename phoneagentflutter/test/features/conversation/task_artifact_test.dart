import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact_projection.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact_download.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/task_artifact_download_controller.dart';

const descriptor = {
  'artifactId': 'skill-template:visa:v1',
  'kind': 'SKILL_TEMPLATE',
  'fileName': '任务模板.docx',
  'mimeType':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'status': 'READY',
};

class _Files
    implements TaskArtifactRepository, TaskFileDestination, TaskFileInspection {
  Completer<Uint8List>? holdDownload;
  Completer<TaskFileSaved?>? holdSave;
  bool failed = false, cancelled = false, present = true;
  @override
  Future<bool> exists(TaskFileSaved saved) async => present;
  int downloads = 0, saves = 0, cancels = 0, opens = 0;
  @override
  Future<Uint8List> download(TaskArtifact artifact) async {
    downloads++;
    if (failed) throw StateError('network');
    return holdDownload == null
        ? Uint8List.fromList([80, 75, 3, 4])
        : holdDownload!.future;
  }

  @override
  Future<TaskFileSaved?> save(
    String id,
    TaskArtifact a,
    Uint8List bytes,
  ) async {
    saves++;
    if (holdSave != null) return holdSave!.future;
    return cancelled ? null : const TaskFileSaved('content://synthetic/file');
  }

  @override
  Future<void> cancel(String id) async {
    cancels++;
  }

  @override
  Future<void> open(TaskFileSaved saved) async {
    opens++;
  }
}

void main() {
  test(
    'live and history share stable template/CSV cards without duplicate overlays',
    () {
      final payload = {
        'toolName': 'provideSkillTemplate',
        'result': {'artifact': descriptor},
      };
      final live = TaskArtifactProjection.messages(payload, 'c');
      final history = ConversationMessages.project([
        LedgerEvent(
          eventId: 'e',
          sessionId: 's',
          sequence: 1,
          type: 'TOOL_RESULT_RECORDED',
          schemaVersion: 1,
          commandId: 'c',
          payload: payload,
        ),
        LedgerEvent(
          eventId: 'e2',
          sessionId: 's',
          sequence: 2,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'c',
          payload: {'text': '模板已准备'},
        ),
      ]);
      expect(live.single.artifact!.fileName, '任务模板.docx');
      expect(
        ConversationMessageMerge.merge(
          history,
          live,
        ).where((m) => m.artifact != null).length,
        1,
      );
      final csv = TaskArtifactProjection.messages({
        'batchCallResult': {
          'artifacts': [
            {
              'artifactId': 'batch-receipt-csv.cw.Yg',
              'kind': 'BATCH_RECEIPT_CSV',
              'fileName': '外呼回执.csv',
              'mimeType': 'text/csv; charset=utf-8',
              'status': 'READY',
              'itemCount': 2,
            },
          ],
        },
      }, 'batch');
      expect(csv.single.artifact!.kind, TaskArtifactKind.batchCsv);
      expect(csv.single.artifact!.itemCount, 2);
      expect(
        TaskArtifact.parse({...descriptor, 'fileName': '../escape.docx'}),
        isNull,
      );
      expect(
        TaskArtifact.parse({
          ...descriptor,
          'artifactId': 'skill-template:x/y:v1',
        }),
        isNull,
      );
    },
  );
  test('duplicate, failure, cancel and retry have distinct outcomes', () async {
    final files = _Files()..holdDownload = Completer<Uint8List>();
    final c = TaskArtifactDownloadController(
      repository: files,
      destination: files,
      isCurrent: () => true,
    );
    final a = TaskArtifact.parse(descriptor)!;
    final first = c.download(a);
    await c.download(a);
    expect(files.downloads, 1);
    files.holdDownload!.complete(Uint8List.fromList([1]));
    await first;
    expect(c.state(a.id).phase, ArtifactDownloadPhase.saved);
    await c.open(a.id);
    expect(files.opens, 1);
    await c.download(a);
    expect(
      files.downloads,
      1,
      reason: 'saved documents cannot be downloaded twice by a stale button',
    );
    c.dispose();
    final retry = TaskArtifactDownloadController(
      repository: files,
      destination: files,
      isCurrent: () => true,
    );
    files.holdDownload = null;
    files.failed = true;
    await retry.download(a);
    expect(retry.state(a.id).phase, ArtifactDownloadPhase.failed);
    files.failed = false;
    files.cancelled = true;
    await retry.download(a);
    expect(retry.state(a.id).phase, ArtifactDownloadPhase.cancelled);
    files.cancelled = false;
    await retry.download(a);
    expect(retry.state(a.id).phase, ArtifactDownloadPhase.saved);
    retry.dispose();
  });
  test('deleted file resets state and permits explicit redownload', () async {
    final files = _Files();
    final c = TaskArtifactDownloadController(
      repository: files,
      destination: files,
      isCurrent: () => true,
    );
    final artifact = TaskArtifact.parse(descriptor)!;
    await c.download(artifact);
    files.present = false;
    await c.refreshSaved();
    expect(c.state(artifact.id).phase, ArtifactDownloadPhase.idle);
    expect(c.state(artifact.id).saved, isNull);
    files.present = true;
    await c.download(artifact);
    expect(files.downloads, 2);
    expect(c.state(artifact.id).phase, ArtifactDownloadPhase.saved);
    files.present = false;
    await c.open(artifact.id);
    expect(files.opens, 0);
    expect(c.state(artifact.id).phase, ArtifactDownloadPhase.idle);
    c.dispose();
  });
  test(
    'late account download never opens save; disposed save is cancelled',
    () async {
      var current = true;
      final files = _Files()..holdDownload = Completer<Uint8List>();
      final c = TaskArtifactDownloadController(
        repository: files,
        destination: files,
        isCurrent: () => current,
      );
      final a = TaskArtifact.parse(descriptor)!;
      final pending = c.download(a);
      current = false;
      files.holdDownload!.complete(Uint8List.fromList([1]));
      await pending;
      expect(files.saves, 0);
      c.dispose();
      current = true;
      files.holdDownload = null;
      files.holdSave = Completer<TaskFileSaved?>();
      final next = TaskArtifactDownloadController(
        repository: files,
        destination: files,
        isCurrent: () => current,
      );
      final save = next.download(a);
      await Future<void>.delayed(Duration.zero);
      next.dispose();
      expect(files.cancels, 1);
      files.holdSave!.complete(null);
      await save;
    },
  );
}
