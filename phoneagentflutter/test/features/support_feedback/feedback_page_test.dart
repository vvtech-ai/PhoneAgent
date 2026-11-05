import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:phone_agent/core/design/native_page_header.dart';
import 'package:phone_agent/features/support_feedback/presentation/feedback_page.dart';
import 'package:phone_agent/features/support_feedback/presentation/feedback_state.dart';

void main() {
  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  testWidgets(
    'selected log checkbox uses the default primary button blue',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: Colors.purple),
          home: FeedbackPage(
            state: const FeedbackState(includeLogs: true),
            onDescription: (_) {},
            onContact: (_) {},
            onLogs: (_) {},
            onAdd: () {},
            onRemove: (_) {},
            onSubmit: () {},
          ),
        ),
      );
      final row = find.byKey(const Key('feedback-logs'));
      await tester.ensureVisible(row);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: row, matching: find.byType(DecoratedBox)),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF0A84FF));
      expect((decoration.border! as Border).top.color, decoration.color);
      final square = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 16 && widget.height == 16,
        ),
      );
      expect(square, findsOneWidget);
    },
    variant: platforms,
  );
  for (final success in [false, true]) {
    testWidgets('Demo primary button is blue for success=$success', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: Colors.purple),
          home: FeedbackPage(
            state: FeedbackState(success: success),
            onDescription: (_) {},
            onContact: (_) {},
            onLogs: (_) {},
            onAdd: () {},
            onRemove: (_) {},
            onSubmit: () {},
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, success ? '完成' : '提交反馈');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final surface = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      expect(surface.color, const Color(0xFF0A84FF));
    }, variant: platforms);
  }
  testWidgets('logs are opt in and the whole row toggles them', (tester) async {
    var checked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(
          state: const FeedbackState(),
          onDescription: (_) {},
          onContact: (_) {},
          onLogs: (value) => checked = value,
          onAdd: () {},
          onRemove: (_) {},
          onSubmit: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('帮助我们排查问题，仅在勾选后随反馈提交'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('帮助我们排查问题，仅在勾选后随反馈提交'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('帮助我们排查问题，仅在勾选后随反馈提交'));
    expect(checked, isTrue);
    expect(find.text('问题描述'), findsOneWidget);
  }, variant: platforms);
  testWidgets('draft back asks before discard and cancel retains page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FeedbackPage(
                  state: const FeedbackState(description: '草稿'),
                  onDescription: (_) {},
                  onContact: (_) {},
                  onLogs: (_) {},
                  onAdd: () {},
                  onRemove: (_) {},
                  onSubmit: () {},
                ),
              ),
            ),
            child: const Text('进入'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入'));
    await tester.pumpAndSettle();
    final onBack = tester
        .widget<NativePageHeader>(find.byType(NativePageHeader))
        .onBack!;
    onBack();
    onBack();
    await tester.pumpAndSettle();
    expect(find.text('放弃本次反馈？'), findsOneWidget);
    expect(find.byType(NativeBusinessDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback-description')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.text('进入'), findsOneWidget);
    expect(find.byType(FeedbackPage), findsNothing);
  }, variant: platforms);

  testWidgets('busy feedback cannot leave or open discard dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(
          state: const FeedbackState(description: '草稿', busy: true),
          onDescription: (_) {},
          onContact: (_) {},
          onLogs: (_) {},
          onAdd: () {},
          onRemove: (_) {},
          onSubmit: () {},
        ),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NativeBusinessDialog), findsNothing);
    expect(find.byType(FeedbackPage), findsOneWidget);
  }, variant: platforms);
}
