import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'package:phone_agent/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_activity_card.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';

void main() {
  final cases = <String, Widget Function(VoidCallback?)>{
    '通用': (tap) => NativeGradientAction(label: '操作', onPressed: tap),
    '登录': (tap) => AuthPrimaryButton(label: '操作', onPressed: tap),
    '购买': (tap) => CommerceAction('操作', onPressed: tap),
    '邀请': (tap) => InvitePrimaryAction(label: '操作', onPressed: tap),
    '克隆': (tap) => ClonePrimaryAction(label: '操作', onPressed: tap),
    '克隆结果': (tap) =>
        ClonePrimaryAction(label: '操作', onPressed: tap, result: true),
  };
  for (final entry in cases.entries) {
    for (final scale in [1.0, 2.0]) {
      for (final enabled in [true, false]) {
        testWidgets('${entry.key} scale=$scale enabled=$enabled', (
          tester,
        ) async {
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 280,
                      child: entry.value(enabled ? () => calls++ : null),
                    ),
                  ),
                ),
              ),
            ),
          );
          final action = find.byWidgetPredicate((w) => w is ButtonStyleButton);
          final button = tester.widget<ButtonStyleButton>(action);
          expect(tester.getSize(action).height, scale == 1 ? 50 : 68);
          final shape = button.style!.shape!.resolve({})!;
          expect(
            (shape as RoundedRectangleBorder).borderRadius,
            BorderRadius.circular(18),
          );
          final text = button.style!.textStyle!.resolve({})!;
          expect(text.fontSize, 15);
          expect(text.fontWeight, FontWeight.w700);
          expect(text.height, 20 / 15);
          final surface = tester
              .widgetList<DecoratedBox>(
                find.ancestor(of: action, matching: find.byType(DecoratedBox)),
              )
              .map((w) => w.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((d) => d.gradient != null);
          expect(
            surface.gradient!.colors,
            enabled
                ? [const Color(0xFF0A84FF), const Color(0xFF0071EB)]
                : [const Color(0xFFEEF2F7), const Color(0xFFE8EDF5)],
          );
          expect(button.onPressed != null, enabled);
          await tester.tap(action);
          expect(calls, enabled ? 1 : 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('购买busy仍阻止重复操作，保留加载文案', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommerceAction('购买处理中', busy: true, onPressed: () => calls++),
        ),
      ),
    );
    expect(find.text('购买处理中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = find.byWidgetPredicate((w) => w is ButtonStyleButton);
    await tester.tap(button);
    expect(calls, 0);
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
