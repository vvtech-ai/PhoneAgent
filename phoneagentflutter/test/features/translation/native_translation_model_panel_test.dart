import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_panel.dart';
import 'support/domestic_model_sheet_fixture.dart';

void main() {
  const capture = bool.fromEnvironment('MODEL_SHEET_CAPTURE');
  setUpAll(() async {
    if (!capture) return;
    for (final font in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      if (font.value.isEmpty) {
        throw StateError('Explicit capture fonts required');
      }
      final loader = FontLoader(font.key)
        ..addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final size in [const Size(390, 844), const Size(320, 480)]) {
        testWidgets('four native options $platform/$scale/$size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await mountSheetDialer(
            tester,
            SheetRepository(),
            scale: scale,
            platform: platform,
          );
          await openSheet(tester);
          final rows = tester
              .widgetList<NativeTranslationModelOption>(
                find.byType(NativeTranslationModelOption),
              )
              .toList();
          expect(rows.map((v) => v.name), [
            'Qwen3.5',
            'Doubao',
            'GPT Live Translate',
            'Gemini Live',
          ]);
          expect(rows.map((v) => v.onSelect != null), [
            true,
            true,
            false,
            false,
          ]);
          expect(find.text('服务器说明'), findsNWidgets(4));
          if (scale == 1) {
            expect(
              tester.getCenter(find.text('推荐')).dx,
              greaterThan(
                tester
                    .getCenter(
                      find.descendant(
                        of: find.byType(NativeTranslationModelPanel),
                        matching: find.text('Qwen3.5'),
                      ),
                    )
                    .dx,
              ),
            );
          }
          if (platform == TargetPlatform.iOS && size.height == 844) {
            expect(
              tester.getSize(find.byType(NativeTranslationModelPanel)).height,
              436,
            );
          }
          if (capture && size.height == 844) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find
                  .ancestor(
                    of: find.byType(NativeTranslationModelPanel),
                    matching: find.byType(RepaintBoundary),
                  )
                  .first,
            );
            await tester.runAsync(() async {
              final pixels = await boundary.toImage(pixelRatio: 3);
              final bytes = await pixels.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory(
                '.local/ui-reference/model-sheet-native-parity',
              )..createSync(recursive: true);
              File(
                '${dir.path}/${platform.name}-${scale.toInt()}x.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              pixels.dispose();
            });
          }
          await tester.ensureVisible(find.text('Gemini Live'));
          await tester.tap(find.text('Gemini Live'));
          await tester.pumpAndSettle();
          expect(find.text('选择实时翻译模型'), findsOneWidget);
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          expect(find.text('选择实时翻译模型'), findsNothing);
          await openSheet(tester);
          await selectDoubao(tester);
          expect(find.text('翻译通话模型已切换为 Doubao'), findsOneWidget);
          {
            final toast = find
                .ancestor(
                  of: find.text('翻译通话模型已切换为 Doubao'),
                  matching: find.byKey(const ValueKey('nativeNoticeSurface')),
                )
                .first;
            expect(
              (tester.widget<DecoratedBox>(toast).decoration as BoxDecoration)
                  .color,
              const Color(0xFAFFFFFF),
            );
          }
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(find.text('翻译通话模型已切换为 Doubao'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
