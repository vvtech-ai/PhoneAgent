import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/domain/record_time.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/translation_task_presentation.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';

const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

TaskRecord withHistorySubtitle(TaskRecord record) => record.copyWith(
  summary: TranslationTaskPresentation.historySubtitle(record),
);

TranslationHistory historyAt(String timestamp) => TranslationHistory(
  callId: 'synthetic-time',
  route: TranslationRoute.worldCall,
  targetName: '合成记录',
  phoneNumber: '',
  myLanguage: 'zh',
  peerLanguage: 'en',
  connectedAt: timestamp,
  endedAt: timestamp,
  durationMillis: 12000,
  transcripts: const [],
);

void main() {
  final clock = DateTime(2026, 10, 9, 18);
  for (final sample in {
    '2026-10-09T14:05:00': '今天 14:05',
    '2026-10-08T14:05:00': '昨天 14:05',
    '2026-10-07T14:05:00': '星期三 14:05',
    '2026-10-03T14:05:00': '星期六 14:05',
    '2026-10-02T14:05:00': '10月2日 14:05',
    '2025-10-09T14:05:00': '2025年10月9日 14:05',
  }.entries) {
    test('native record date boundary ${sample.key}', () {
      expect(recordTimeLabel(sample.key, now: clock), sample.value);
    });
  }
  test('calendar day survives DST and year boundary', () {
    expect(
      recordTimeLabel('2026-03-08T00:05:00', now: DateTime(2026, 3, 9)),
      '昨天 00:05',
    );
    expect(
      recordTimeLabel('2025-12-30T14:05:00', now: DateTime(2026, 1, 2)),
      '星期二 14:05',
    );
  });
  test('offset timestamp is displayed in local time', () {
    const raw = '2026-10-07T12:05:00+08:00';
    final local = DateTime.parse(raw).toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final expectedClock =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(recordTimeLabel(raw, now: today), '今天 $expectedClock');
  });
  test('invalid fallbacks remain caller controlled', () {
    expect(recordTimeLabel('invalid', now: clock), '');
    expect(
      recordTimeLabel('invalid', now: clock, invalidFallback: 'invalid'),
      'invalid',
    );
    expect(recordTimeLabel('', now: clock), '');
  });
  final now = DateTime.now();
  final recent = DateTime(now.year, now.month, now.day - 2, 14, 5);
  final old = DateTime(now.year - 1, 1, 2, 14, 5);
  final recentLabel = '${weekdays[recent.weekday - 1]} 14:05';

  test('history uses recent native weekday without changing metadata', () {
    final history = historyAt(recent.toIso8601String());
    final content = TranslationHistoryContent.from(history);
    expect(content.time, recentLabel);
    expect(content.duration, '00:12');
    expect(history.connectedAt, recent.toIso8601String());
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('task uses weekday and cross-year date on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: TasksPage(
              state: TaskState(
                catalog: TaskCatalog([
                  withHistorySubtitle(
                    TaskRecord(
                      id: 'recent',
                      kind: TaskRecordKind.translation,
                      title: '合成记录',
                      status: TaskStatus.completed,
                      rawStatus: 'ENDED',
                      timestamp: recent.toIso8601String(),
                      durationMillis: 12000,
                    ),
                  ),
                  withHistorySubtitle(
                    TaskRecord(
                      id: 'old',
                      kind: TaskRecordKind.translation,
                      title: '跨年记录',
                      status: TaskStatus.completed,
                      rawStatus: 'ENDED',
                      timestamp: old.toIso8601String(),
                      durationMillis: 12000,
                    ),
                  ),
                ]),
              ),
              onRefresh: () async {},
              onOpen: (_) {},
            ),
          ),
        ),
      );
      expect(find.text(recentLabel), findsOneWidget);
      expect(find.text('${old.year}年1月2日 14:05'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('translation without history preserves empty detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksPage(
            state: TaskState(
              catalog: TaskCatalog([
                TaskRecord(
                  id: 'unmatched',
                  kind: TaskRecordKind.translation,
                  title: '无匹配历史',
                  status: TaskStatus.completed,
                  rawStatus: 'ENDED',
                  timestamp: recent.toIso8601String(),
                ),
              ]),
            ),
            onRefresh: () async {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('无匹配历史'), findsOneWidget);
    expect(find.text(recentLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
