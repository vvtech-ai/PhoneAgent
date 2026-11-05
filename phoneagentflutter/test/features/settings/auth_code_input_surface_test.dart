import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/auth_tokens.dart';
import 'package:phone_agent/features/auth/presentation/widgets/auth_widgets.dart';

Future<ui.Image> _image(WidgetTester tester) => tester
    .runAsync(
      () => tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('code-surface')),
          )
          .toImage(),
    )
    .then((image) => image!);

Future<int> _gapInk(WidgetTester tester) async {
  final origin = tester.getTopLeft(find.byKey(const Key('code-surface')));
  final cells = find.byType(AuthInputGroup);
  final image = await _image(tester);
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  var ink = 0;
  for (var i = 0; i < 5; i++) {
    final left = (tester.getTopRight(cells.at(i)).dx - origin.dx).ceil() + 2;
    final right =
        (tester.getTopLeft(cells.at(i + 1)).dx - origin.dx).floor() - 2;
    for (var x = left; x < right; x++) {
      for (var y = 0; y < image.height; y++) {
        if (data.getUint8((y * image.width + x) * 4 + 3) != 0) ink++;
      }
    }
  }
  image.dispose();
  return ink;
}

void main() {
  testWidgets(
    'resend clear/disable/focus transition never paints text between code cells',
    (tester) async {
      final code = TextEditingController(text: '12345');
      final focus = FocusNode();
      addTearDown(code.dispose);
      addTearDown(focus.dispose);
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return SizedBox(
                    width: 320,
                    child: RepaintBoundary(
                      key: const Key('code-surface'),
                      child: AuthCodeInput(
                        controller: code,
                        focusNode: focus,
                        enabled: enabled,
                        onChanged: (_) {},
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(await _gapInk(tester), 0);
      // A resend clears the field and temporarily disables it, then restores focus.
      code.clear();
      focus.unfocus();
      update(() => enabled = false);
      for (final duration in [
        Duration.zero,
        const Duration(milliseconds: 80),
        const Duration(milliseconds: 200),
      ]) {
        await tester.pump(duration);
        expect(
          await _gapInk(tester),
          0,
          reason: 'disabled/empty frame must contain only the six cells',
        );
      }
      update(() => enabled = true);
      await tester.pump();
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(await _gapInk(tester), 0);
      final input = find.byKey(const Key('verification-code-input'));
      await tester.enterText(input, '654321');
      await tester.pump();
      expect(code.text, '654321');
      expect(await _gapInk(tester), 0);
      expect(
        tester.widget<TextField>(input).autofillHints,
        contains(AutofillHints.oneTimeCode),
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('6位验证码'), findsWidgets);
      semantics.dispose();
    },
  );

  testWidgets(
    'all six backgrounds stay visibly gray and opaque while disabled',
    (tester) async {
      final code = TextEditingController();
      addTearDown(code.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: RepaintBoundary(
                  key: const Key('code-surface'),
                  child: AuthCodeInput(
                    controller: code,
                    enabled: false,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final image = await _image(tester);
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final origin = tester.getTopLeft(find.byKey(const Key('code-surface')));
      final cells = find.byType(AuthInputGroup);
      for (var i = 0; i < 6; i++) {
        final position = tester.getCenter(cells.at(i)) - origin;
        final index = (8 * image.width + position.dx.round()) * 4;
        final color = Color.fromARGB(
          bytes.getUint8(index + 3),
          bytes.getUint8(index),
          bytes.getUint8(index + 1),
          bytes.getUint8(index + 2),
        );
        expect(color.a, 1);
        expect(
          color.computeLuminance(),
          lessThan(0.87),
          reason: 'near-white fill is indistinguishable from the page',
        );
      }
      image.dispose();
      expect(
        AuthTokens.field,
        const Color(0xFFF5F7FA),
        reason: 'ordinary auth fields keep their existing style',
      );
    },
  );
}
