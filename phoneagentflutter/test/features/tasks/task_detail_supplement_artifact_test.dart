import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/task_artifact_providers.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact_download.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/task_artifact_download_controller.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_detail_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_detail_page.dart';
import 'task_detail_controller_test.dart' show row;

class _Files implements TaskArtifactRepository, TaskFileDestination {
  int downloads = 0, saves = 0, opens = 0;
  @override
  Future<Uint8List> download(TaskArtifact artifact) async {
    downloads++;
    return Uint8List.fromList([1, 2]); // Synthetic bytes; no actual document.
  }

  @override
  Future<TaskFileSaved?> save(
    String id,
    TaskArtifact artifact,
    Uint8List bytes,
  ) async {
    saves++;
    return const TaskFileSaved('synthetic:document');
  }

  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> open(TaskFileSaved saved) async {
    opens++;
  }
}

void main() {
  testWidgets(
    'terminal detail projects supplementary Q/A and explicit artifact save without replay',
    (tester) async {
      final files = _Files(), owner = Object();
      final downloads = TaskArtifactDownloadController(
        repository: files,
        destination: files,
        isCurrent: () => true,
      );
      final restored = RestoredConversation(
        const ConversationDetail(
          sessionId: 'same',
          title: '合成终态任务',
          status: 'COMPLETED',
        ),
        ledger: LedgerSnapshot(
          'same',
          2,
          const LedgerProjection(
            status: 'COMPLETED',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 2,
          ),
          [
            LedgerEvent(
              eventId: 'supplement',
              sessionId: 'same',
              sequence: 1,
              schemaVersion: 1,
              type: 'CALL_CONFIRMATION_SUPPLEMENT',
              payload: {
                'recordId': 'q1',
                'pendingToolCallId': 't1',
                'userText': '任务会马上拨打吗？',
                'assistantText': '需要明确确认后才会拨打。',
              },
            ),
            LedgerEvent(
              eventId: 'artifact',
              sessionId: 'same',
              sequence: 2,
              schemaVersion: 1,
              type: 'TOOL_RESULT_RECORDED',
              payload: {
                'result': {
                  'artifact': {
                    'artifactId': 'skill-template:restaurant_booking:v1',
                    'kind': 'SKILL_TEMPLATE',
                    'fileName': '合成模板.docx',
                    'mimeType':
                        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                    'status': 'READY',
                  },
                },
              },
            ),
          ],
        ),
      );
      var restores = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskArtifactDownloadProvider(owner).overrideWith((_) => downloads),
          ],
          child: MaterialApp(
            home: TaskDetailPage(
              state: TaskDetailState(row, restored: restored),
              artifactOwner: owner,
              onClose: () {},
              onRetry: () {},
              onRestore: () => restores++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('状态：已完成'), findsOneWidget);
      expect(find.text('任务会马上拨打吗？'), findsOneWidget);
      expect(find.text('需要明确确认后才会拨打。'), findsOneWidget);
      expect(files.downloads, 0);
      final download = find.text('下载模板');
      await tester.ensureVisible(download);
      await tester.pumpAndSettle();
      await tester.tap(download);
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(files.downloads, 1);
      expect(files.saves, 1);
      final openFile = find.widgetWithText(FilledButton, '查看');
      expect(openFile, findsOneWidget);
      await tester.tap(openFile);
      await tester.pumpAndSettle();
      expect(files.opens, 1);
      await tester.tap(find.byKey(const ValueKey('task-detail-restore')));
      await tester.pumpAndSettle();
      expect(restores, 1);
      expect(files.downloads, 1);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
