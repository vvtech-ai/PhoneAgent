import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_clone_entry.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform clone readiness scale=$scale', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var opens = 0;
        Future<void> show(
          bool? ready, {
          bool failed = false,
          bool busy = false,
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: NativeCloneEntry(
                        hasReadyClone: ready,
                        failed: failed,
                        onTap: busy ? null : () => opens++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(null);
        expect(find.text('正在读取声音克隆状态...'), findsOneWidget);
        expect(find.text('还没有克隆音色，完成声音克隆后即可使用。'), findsNothing);
        await show(false);
        expect(find.text('还没有克隆音色，完成声音克隆后即可使用。'), findsOneWidget);
        await show(true);
        expect(find.text('克隆音色已完成，可在支持声音克隆的语音模型中选择使用。'), findsOneWidget);
        await show(null, failed: true);
        expect(find.text('声音克隆状态暂不可用，请稍后重试。'), findsOneWidget);
        final action = find.byKey(const ValueKey('model-create-clone'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(opens, 1);
        await show(true, busy: true);
        await tester.ensureVisible(action);
        await tester.tap(action);
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
