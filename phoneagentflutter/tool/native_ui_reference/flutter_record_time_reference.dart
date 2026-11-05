import 'package:flutter/material.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/translation_task_presentation.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: const _RecordTimeReference(),
  ),
);

class _RecordTimeReference extends StatefulWidget {
  const _RecordTimeReference();
  @override
  State<_RecordTimeReference> createState() => _RecordTimeReferenceState();
}

class _RecordTimeReferenceState extends State<_RecordTimeReference> {
  late final List<TaskRecord> _records;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _records = [
      _record(
        'recent-record',
        '合成近期记录',
        DateTime(now.year, now.month, now.day - 2, 14, 5),
      ),
      _record(
        'previous-year-record',
        '合成跨年记录',
        DateTime(now.year - 1, 1, 2, 14, 5),
      ),
    ];
  }

  TaskRecord _record(String id, String title, DateTime time) {
    final record = TaskRecord(
      id: id,
      kind: TaskRecordKind.translation,
      title: title,
      timestamp: time.toIso8601String(),
      status: TaskStatus.completed,
      rawStatus: 'ENDED',
      durationMillis: 12000,
    );
    return record.copyWith(
      summary: TranslationTaskPresentation.historySubtitle(record),
    );
  }

  Future<void> _open(TaskRecord record) async {
    if (_opening || !mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _opening = true;
    final detail = TranslationHistory(
      callId: record.id,
      route: TranslationRoute.worldCall,
      targetName: record.title,
      phoneNumber: '',
      myLanguage: 'zh',
      peerLanguage: 'en',
      connectedAt: record.timestamp,
      endedAt: record.timestamp,
      durationMillis: 12000,
      transcripts: const [],
    );
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (route) => Scaffold(
            body: SafeArea(
              child: TranslationHistoryPage(
                state: TranslationHistoryState(
                  content: TranslationHistoryContent.from(detail),
                ),
                onClose: () => Navigator.of(route).pop(),
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: TasksPage(
        state: TaskState(catalog: TaskCatalog(_records)),
        onRefresh: () async {},
        onOpen: _open,
      ),
    ),
  );
}
