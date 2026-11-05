import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/task_artifact_providers.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact_download.dart';
import 'package:phone_agent/features/conversation/presentation/controller/task_artifact_download_controller.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/task_artifact_card.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/presentation/controller/call_evaluation_controller.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/call_evaluation_card.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_entry.dart';
import '../../support/pump_ui_transitions.dart';

class _Files implements TaskArtifactRepository, TaskFileDestination {
  Completer<Uint8List> request = Completer<Uint8List>();
  int opens = 0;
  @override
  Future<Uint8List> download(TaskArtifact artifact) => request.future;
  @override
  Future<TaskFileSaved?> save(
    String id,
    TaskArtifact artifact,
    Uint8List data,
  ) async => const TaskFileSaved('synthetic.csv');
  @override
  Future<void> open(TaskFileSaved file) async {
    opens++;
  }

  @override
  Future<void> cancel(String id) async {}
}

void main() {
  testWidgets('shared timeline separates CSV and final reply after ratings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final output = Platform.environment['PHONEAGENT_PARITY_SCREENSHOT_DIR'];
    if (output != null) {
      final font = (await tester.runAsync(
        () => File('C:/Windows/Fonts/msyh.ttc').readAsBytes(),
      ))!;
      await (FontLoader(
        'ParityFont',
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
      final icons = (await tester.runAsync(
        () => File(
          'D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes(),
      ))!;
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    }
    final files = _Files();
    final controller = TaskArtifactDownloadController(
      repository: files,
      destination: files,
      isCurrent: () => true,
    );
    final messages = ConversationMessages.project([
      LedgerEvent(
        eventId: 'final',
        sessionId: 's',
        sequence: 1,
        schemaVersion: 1,
        type: 'ASSISTANT_TURN_COMMITTED',
        commandId: 'c',
        payload: {
          'text': '任务已结束，结果见上方。',
          'batchCallResult': {
            'batchId': 'b',
            'status': 'COMPLETED',
            'totalCount': 2,
            'items': [
              {
                'itemId': 'one',
                'targetName': '合成联系人甲',
                'status': 'SUCCESS',
                'headline': '已确认参会',
              },
              {
                'itemId': 'two',
                'targetName': '合成联系人乙',
                'status': 'FAILED',
                'headline': '未接通',
              },
            ],
            'artifacts': [
              {
                'artifactId': 'batch-receipt-csv.s.b',
                'kind': 'BATCH_RECEIPT_CSV',
                'sourceBatchId': 'b',
                'status': 'READY',
                'fileName': '合成批量外呼回执.csv',
                'mimeType': 'text/csv',
                'itemCount': 2,
              },
            ],
          },
        },
      ),
    ]);
    final boundary = GlobalKey();
    Widget app(Widget child) => ProviderScope(
      overrides: [
        taskArtifactDownloadProvider.overrideWith((ref, owner) => controller),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: ThemeData(fontFamily: output == null ? null : 'ParityFont'),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpWidget(
      app(
        ConversationPage(
          state: ConversationState(
            entry: const ConversationEntry(sessionId: 's'),
            messages: messages,
          ),
          artifactOwner: 'test',
          modelName: 'Seeduplex',
          onClose: () {},
          onToggle: () {},
          onSend: (_) => false,
          onChoose: (_, __) => false,
          onRetry: () {},
          onNotice: (_) {},
          onModels: () {},
          receiptFeedbackBuilder: (m) => m.batchReceipt == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CallEvaluationCard(
                      state: const CallEvaluationState(
                        evaluation: CallEvaluation(
                          target: FeedbackTarget(FeedbackTargetKind.batch, 'b'),
                          modelName: 'Seeduplex',
                          minimumLatencyMs: 120,
                          maximumLatencyMs: 240,
                        ),
                      ),
                      onRate: (_) {},
                    ),
                    NativeTaskRatingEntry(readOnly: false, onOpen: () {}),
                  ],
                ),
        ),
      ),
    );
    await tester.pumpUntilUiSettled();
    final result = tester.getRect(find.text('执行结果'));
    final model = tester.getRect(find.text('使用模型'));
    final rating = tester.getRect(find.byType(NativeTaskRatingEntry));
    final artifact = tester.getRect(find.byType(TaskArtifactCard));
    final finalBubble = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('message:ledger:final')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(result.bottom, lessThan(model.top));
    expect(model.bottom, lessThan(rating.top));
    expect(rating.bottom, lessThanOrEqualTo(artifact.top));
    expect(finalBubble.top - artifact.bottom, greaterThanOrEqualTo(9));
    expect(tester.takeException(), isNull);
    Future<void> capture(String name) async {
      if (output == null) return;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('batch-result-order');
    await tester.pumpWidget(
      app(
        const Align(
          alignment: Alignment.topLeft,
          child: NativeThinkingCard(
            processing: false,
            steps: ['正在理解任务', '已确认联系人', '正在执行多路外呼', '正在等待结果回传', '正在整理通话结果'],
          ),
        ),
      ),
    );
    await tester.pumpUntilUiSettled();
    await capture('thinking-completed');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native receipt labels, green actions and download lifecycle', (
    tester,
  ) async {
    final files = _Files();
    final controller = TaskArtifactDownloadController(
      repository: files,
      destination: files,
      isCurrent: () => true,
    );
    const artifact = TaskArtifact(
      id: 'batch-receipt-csv.s.b',
      kind: TaskArtifactKind.batchCsv,
      fileName: '测试回执.csv',
      mimeType: 'text/csv',
      status: 'READY',
      itemCount: 2,
      sourceBatchId: 'b',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskArtifactDownloadProvider.overrideWith((ref, owner) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskArtifactCard(artifact: artifact, owner: 'test'),
          ),
        ),
      ),
    );
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('2 条回执'), findsOneWidget);
    expect(find.text('下载回执'), findsOneWidget);
    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((box) => box.gradient)
        .whereType<LinearGradient>();
    expect(
      gradients.any((g) => g.colors.contains(const Color(0xFF34C759))),
      isTrue,
    );
    await tester.tap(find.text('下载回执'));
    await tester.pump();
    expect(find.text('下载中'), findsOneWidget);
    files.request.completeError(StateError('synthetic failure'));
    await tester.pump();
    expect(find.text('重试'), findsOneWidget);
    files.request = Completer<Uint8List>();
    await tester.tap(find.text('重试'));
    files.request.complete(Uint8List.fromList([1, 2]));
    await tester.pump();
    expect(find.text('查看'), findsOneWidget);
    await tester.tap(find.text('查看'));
    await tester.pump();
    expect(files.opens, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
