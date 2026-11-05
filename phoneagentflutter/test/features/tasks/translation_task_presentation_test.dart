import 'package:flutter/material.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/tasks/data/api_task_repository.dart';
import 'package:phone_agent/features/tasks/data/translation_task_history_projection.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/translation_task_presentation.dart';
import '../../support/synthetic_account_api.dart';

TaskRecord record({
  String title = '原始标题',
  String call = 'one',
  int? duration,
  String raw = 'ENDED',
  String start = '',
  String end = '',
  String phone = '',
}) => TaskRecord(
  id: call,
  callId: call,
  kind: TaskRecordKind.translation,
  title: title,
  status: TaskStatus.completed,
  rawStatus: raw,
  durationMillis: duration,
  startedAt: start,
  timestamp: end,
  phoneNumber: phone,
);

void main() {
  test('duration priority, text, time difference, invalid and negative', () {
    expect(
      TranslationTaskPresentation.duration(
        record(duration: 12000, raw: '99:99'),
      ),
      '00:12',
    );
    expect(
      TranslationTaskPresentation.duration(record(raw: '01:02:03')),
      '01:02:03',
    );
    expect(
      TranslationTaskPresentation.duration(
        record(start: '2026-10-12T10:00:00', end: '2026-10-12T10:01:02'),
      ),
      '01:02',
    );
    expect(
      TranslationTaskPresentation.duration(
        record(start: '2026-10-12T10:01:00', end: '2026-10-12T10:00:00'),
      ),
      '00:00',
    );
    expect(TranslationTaskPresentation.duration(record(start: 'bad')), '');
    expect(
      TranslationTaskPresentation.duration(
        record(start: '2026-10-12', end: '2026-10-13'),
      ),
      '',
    );
  });
  test(
    'history subtitle uses start time, then occurrence, then Android fallback',
    () {
      final now = DateTime(2026, 10, 12, 12);
      expect(
        TranslationTaskPresentation.historySubtitle(
          record(start: '2026-10-12T10:00:00', end: '2026-10-12T11:00:00'),
          now: now,
        ),
        '今天 10:00',
      );
      expect(
        TranslationTaskPresentation.historySubtitle(
          record(start: 'bad', end: '2026-10-11T11:00:00'),
          now: now,
        ),
        '昨天 11:00',
      );
      expect(
        TranslationTaskPresentation.historySubtitle(record(), now: now),
        '刚刚',
      );
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('translation second line keeps projected detail on $platform', (
      tester,
    ) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: TasksPage(
              state: TaskState(
                catalog: TaskCatalog([
                  record(
                    start: '2020-01-02T03:04:05',
                  ).copyWith(summary: '服务端第二行'),
                ]),
              ),
              onRefresh: () async {},
              onOpen: (_) => opens++,
            ),
          ),
        ),
      );
      expect(find.text('服务端第二行'), findsOneWidget);
      expect(find.textContaining('2020年'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('one')));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'history title strips prefixes, rejects placeholders and uses number',
    () {
      for (final title in ['拨打 张三', '翻译通话 张三', '张三']) {
        expect(
          TranslationTaskPresentation.historyTitle(record(title: title)),
          '实时翻译 · 张三',
        );
      }
      expect(
        TranslationTaskPresentation.historyTitle(
          record(title: '未知联系人', phone: '123'),
        ),
        '实时翻译 · 123',
      );
      expect(
        TranslationTaskPresentation.historyTitle(record(title: '对方')),
        '实时翻译 · 未知号码',
      );
    },
  );
  test(
    'projection matches call identity and preserves authoritative page fields',
    () {
      final row = record(duration: 12000);
      final page = TaskPage(
        pinnedItems: [row],
        items: [record(call: 'other')],
        nextOffset: 15,
        hasMore: true,
        hasUnread: true,
      );
      final result = projectTranslationTaskHistory(page, [
        record(title: '拨打 张三', duration: 99000),
      ]);
      expect(result.pinnedItems.single.title, '实时翻译 · 张三');
      expect(result.pinnedItems.single.durationMillis, 12000);
      expect(result.pinnedItems.single.summary, '刚刚');
      expect(result.pinnedItems.single.startedAt, row.startedAt);
      expect(result.pinnedItems.single.timestamp, row.timestamp);
      expect(result.items.single.title, '原始标题');
      expect(result.nextOffset, 15);
      expect(result.hasMore, true);
      expect(result.hasUnread, true);
    },
  );
  test(
    'repository enriches matching history; errors preserve page except session change',
    () async {
      final wire = SyntheticAccountApi();
      final dto = {
        'resourceType': 'REALTIME_TRANSLATION',
        'resourceId': 'one',
        'title': '原始标题',
        'status': 'ENDED',
        'detail': '服务端说明',
        'sceneType': 'REALTIME_TRANSLATION',
        'createdAt': '2026-10-12T10:00:00',
        'updatedAt': '2026-10-12T10:01:02',
        'canDelete': true,
        'unreadResult': false,
      };
      final page = {
        'pinnedItems': [],
        'items': [dto],
        'nextOffset': 1,
        'hasMore': false,
        'hasUnread': false,
      };
      var mode = 'ok';
      wire.beforeResponse = (request) async {
        if (request.uri.path.endsWith('call-history')) {
          if (mode == 'session') {
            wire.credentials = const AccountCredentials('b', 'synthetic', 2);
          }
          wire.data = mode == 'bad'
              ? {}
              : [
                  {
                    'callId': 'one',
                    'targetName': '拨打 张三',
                    'sceneType': 'REALTIME_TRANSLATION',
                    'callState': 'ENDED',
                    'durationMillis': 12000,
                    'createdAt': '2020-01-02T03:04:05',
                    'updatedAt': '2020-01-02T03:05:00',
                  },
                ];
        } else if (request.uri.path.endsWith('/pin')) {
          wire.data = {...dto, 'pinnedAt': '2026-10-12'};
        } else {
          wire.data = page;
        }
      };
      final repo = ApiTaskRepository(wire.api, 'a');
      final enriched = (await repo.loadPage()).items.single;
      expect(enriched.title, '实时翻译 · 张三');
      expect(enriched.durationMillis, 12000);
      expect(enriched.summary, '2020年1月2日 03:04');
      expect(enriched.startedAt, dto['createdAt']);
      final pinned = await repo.updatePin(
        const TaskRef(TaskResourceType.realtimeTranslation, 'one'),
        true,
      );
      expect(pinned.title, '实时翻译 · 张三');
      expect(pinned.summary, '2020年1月2日 03:04');
      expect(pinned.pinnedAt, '2026-10-12');
      expect(wire.requests.last.headers['Authorization'], 'Bearer synthetic');
      mode = 'bad';
      final fallback = (await repo.loadPage()).items.single;
      expect(fallback.title, '原始标题');
      expect(fallback.summary, '服务端说明');
      expect(TranslationTaskPresentation.duration(fallback), '01:02');
      mode = 'session';
      await expectLater(repo.loadPage(), throwsA(ApiFailure.sessionChanged));
    },
  );
}
