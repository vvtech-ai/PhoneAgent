import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_presets.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';

void main() {
  const capture = bool.fromEnvironment('PRESETS_CAPTURE');
  setUpAll(() async {
    if (!capture) return;
    for (final font in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final size in [const Size(390, 844), const Size(320, 480)]) {
        testWidgets('native presets $platform/$scale/$size', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final setup = TranslationSetupController();
          addTearDown(setup.dispose);
          bool? confirmed;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: platform,
                fontFamily: capture ? 'ReferenceText' : null,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: const Key('preset-render'),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async =>
                        confirmed = await showTranslationPresets(
                          context,
                          setup,
                          setup.enable,
                        ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开'));
          await tester.pumpAndSettle();
          expect(find.text('我方'), findsOneWidget);
          expect(find.text('对方'), findsOneWidget);
          expect(find.text('关闭'), findsNothing);
          expect(find.byTooltip('关闭'), findsOneWidget);
          expect(find.text('海外模型与服务区域'), findsNothing);
          final caller = find.byKey(const Key('translation-caller'));
          final peer = find.byKey(const Key('translation-peer'));
          if (scale == 1) {
            expect(tester.getSize(caller).height, 46);
            expect(
              tester.getTopLeft(peer).dx - tester.getTopRight(caller).dx,
              10,
            );
            final toggle = find.descendant(
              of: find.byKey(const Key('translation-enabled')),
              matching: find.byType(CustomPaint),
            );
            expect(tester.getSize(toggle), const Size(34, 20));
          }
          if (capture && size.height == 844) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('preset-render')),
            );
            await tester.runAsync(() async {
              final pixels = await boundary.toImage(pixelRatio: 3);
              final bytes = await pixels.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('.local/ui-reference/translation-presets')
                ..createSync(recursive: true);
              File(
                '${dir.path}/${platform.name}-${scale.toInt()}x.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              pixels.dispose();
            });
          }
          await tester.ensureVisible(
            find.byKey(const Key('translation-enabled')),
          );
          await tester.tap(find.byKey(const Key('translation-enabled')));
          await tester.pumpAndSettle();
          expect(setup.snapshot.enabled, isFalse);
          expect(tester.widget<OutlinedButton>(caller).onPressed, isNull);
          final call = find.widgetWithText(FilledButton, '普通呼叫');
          await tester.ensureVisible(call);
          await tester.pumpAndSettle();
          expect(tester.getSize(call).height, greaterThanOrEqualTo(54));
          await tester.tap(call);
          await tester.pumpAndSettle();
          expect(confirmed, isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
