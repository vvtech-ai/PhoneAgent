import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_detail_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_welcome_controller.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_welcome_content.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/translation_history_load_state.dart';

void main() {
  for (final kind in ['task', 'welcome', 'history']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$kind primary scale=$scale retains availability', (
        tester,
      ) async {
        var calls = 0;
        final screen = switch (kind) {
          'task' => TaskDetailPage(
            state: const TaskDetailState(
              TaskRecord(
                id: 'synthetic',
                sessionId: 'synthetic',
                title: '合成任务',
                kind: TaskRecordKind.conversation,
                status: TaskStatus.incomplete,
                rawStatus: 'DRAFT',
              ),
            ),
            onClose: () {},
            onRetry: () {},
            onRestore: () => calls++,
          ),
          'welcome' => InviteWelcomeContent(
            code: 'synthetic',
            state: const InviteWelcomeState(canContinue: true),
            onBack: () {},
            onContinue: () => calls++,
            onRetry: () {},
          ),
          _ => Scaffold(
            body: TranslationHistoryLoadState(
              loading: false,
              failed: true,
              closeButton: const SizedBox(),
              onRetry: () => calls++,
            ),
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(FilledButton);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getSize(button).height, greaterThanOrEqualTo(50));
        expect(
          tester.widget<FilledButton>(button).onPressed != null,
          kind != 'task',
        );
        await tester.tap(button);
        expect(calls, kind == 'task' ? 0 : 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
