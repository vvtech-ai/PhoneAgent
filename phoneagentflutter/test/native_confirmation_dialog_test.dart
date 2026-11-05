import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_confirmation_dialog.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform shared confirmation supports short large-text flow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('打开'),
                onPressed: () async {
                  confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => const NativeConfirmationDialog(
                      title: '将替换当前认证身份',
                      message:
                          '检测到本次认证人与当前已认证身份不是同一人。继续后，仅在新身份认证成功时更新身份信息，并使原身份创建的克隆音色不可用。',
                      confirmLabel: '继续并替换',
                      danger: true,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
      final action = find.widgetWithText(TextButton, '继续并替换');
      expect(
        tester
            .widget<NativeGradientAction>(
              find.ancestor(
                of: action,
                matching: find.byType(NativeGradientAction),
              ),
            )
            .tone,
        NativeActionTone.danger,
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
