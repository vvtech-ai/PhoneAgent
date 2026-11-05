import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dialer_bottom_actions.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform empty delete disabled and call shadow follows mode',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var hasInput = false, busy = false, translation = true;
        var deleted = 0, cleared = 0, dialed = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return DialerBottomActions(
                    busy: busy,
                    hasInput: hasInput,
                    translationEnabled: translation,
                    dialLabel: '呼叫',
                    onClose: () {},
                    onDial: () => dialed++,
                    onDelete: () => deleted++,
                    onClear: () => cleared++,
                  );
                },
              ),
            ),
          ),
        );
        final deletion = find.bySemanticsLabel('删除号码，长按清空');
        void checkDelete(bool enabled) {
          expect(
            tester.getSemantics(deletion),
            matchesSemantics(
              label: '删除号码，长按清空',
              isButton: true,
              hasEnabledState: true,
              isEnabled: enabled,
              hasTapAction: enabled,
              hasLongPressAction: enabled,
            ),
          );
        }

        void checkShadow(Color color) {
          final box =
              tester
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: find.byKey(const Key('dial-call')),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          expect(box.boxShadow!.single.color, color.withValues(alpha: .28));
          expect(box.boxShadow!.single.blurRadius, 14);
          expect(box.boxShadow!.single.offset, const Offset(0, 8));
        }

        checkDelete(false);
        checkShadow(const Color(0xFF6C5CE7));
        await tester.tap(find.byKey(const Key('dial-delete')));
        await tester.longPress(find.byKey(const Key('dial-delete')));
        await tester.tap(find.byKey(const Key('dial-call')));
        expect(deleted, 0);
        expect(cleared, 0);
        expect(dialed, 1);
        rebuild(() {
          hasInput = true;
          translation = false;
        });
        await tester.pump();
        checkDelete(true);
        checkShadow(const Color(0xFF34C759));
        await tester.tap(find.byKey(const Key('dial-delete')));
        await tester.longPress(find.byKey(const Key('dial-delete')));
        expect(deleted, 1);
        expect(cleared, 1);
        rebuild(() => busy = true);
        await tester.pump();
        checkDelete(false);
        await tester.tap(find.byKey(const Key('dial-call')));
        expect(dialed, 1);
        semantics.dispose();
      },
    );
  }
}
