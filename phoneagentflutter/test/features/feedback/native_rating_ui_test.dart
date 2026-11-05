import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_entry.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import '../../support/rating_fakes.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform native rating entry and large text no defaults', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: NativeTaskRatingEntry(
                readOnly: false,
                rewardHint: '提交后可获得7积分',
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('为本次任务评分，可获得7积分。'), findsOneWidget);
      expect(find.text('去评分'), findsOneWidget);
      expect(tester.takeException(), isNull);
      var state = TaskRatingState(eligibility: ratingEligibility(clone: true));
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: TaskRatingSheet(
                state: state,
                onClose: () {},
                onRate: (_, _) {},
                onSkipClone: (_) {},
                onSuggestion: (_) {},
                onSubmit: () {},
                onRetryDraft: () {},
              ),
            ),
          ),
        ),
      );
      await show();
      expect(find.text('必填'), findsWidgets);
      expect(find.text('AI大模型对任务的理解（必填）'), findsNothing);
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '提交评价'),
      );
      expect(submit.onPressed, isNull);
      expect(
        submit.style!.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFB4D6F2),
      );
      final score = find.byKey(const ValueKey('rating-understanding-1'));
      final scoreText = tester.widget<Text>(
        find.descendant(of: score, matching: find.byType(Text)),
      );
      expect(scoreText.style!.fontSize, 16);
      expect(scoreText.style!.color, const Color(0xFF14213D));
      await tester.scrollUntilVisible(find.text('未试听 / 不评价'), 180);
      await tester.scrollUntilVisible(find.byType(TextFormField), 180);
      expect(find.text('选填'), findsOneWidget);
      expect(tester.takeException(), isNull);
      state = state.copy(draft: state.draft.edit(skipClone: true));
      await show();
      await tester.scrollUntilVisible(
        find.text('未试听 / 不评价'),
        -180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('未试听 / 不评价'))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      state = state.copy(
        eligibility: ratingEligibility(
          clone: true,
          submission: const TaskRatingSubmission(
            version: 1,
            draft: completeRating,
            rewardGranted: true,
          ),
        ),
        draft: completeRating,
      );
      await show();
      expect(find.text('查看评分'), findsOneWidget);
      expect(find.text('提交评价'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rating-understanding-4')),
        -180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('rating-understanding-4')),
            )
            .onPressed,
        isNull,
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
