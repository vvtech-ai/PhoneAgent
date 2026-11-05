import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/native_dial_pad.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/native_dial_number_header.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_dial_summary.dart';

void main() {
  const capture = bool.fromEnvironment('DIAL_LAYOUT_CAPTURE');
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
    testWidgets('native key label geometry $platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: platform,
            fontFamily: capture ? 'ReferenceText' : null,
          ),
          home: Scaffold(body: NativeDialPad(onDigit: (_) {})),
        ),
      );
      final key = find.byKey(const Key('dial-key-2'));
      final digit = find.byKey(const Key('dial-digit-2'));
      final sub = find.byKey(const Key('dial-letters-2'));
      expect(tester.getSize(key).height, 64);
      if (platform == TargetPlatform.iOS) {
        expect(
          tester.getCenter(digit).dy - tester.getCenter(key).dy,
          closeTo(-7, .01),
        );
        expect(
          tester.getTopLeft(sub).dy - tester.getBottomLeft(digit).dy,
          closeTo(2, .01),
        );
      } else {
        expect(
          (tester.getTopLeft(digit).dy + tester.getBottomLeft(sub).dy) / 2,
          closeTo(tester.getCenter(key).dy, .01),
        );
      }
      expect(
        tester.getCenter(find.byKey(const Key('dial-digit-1'))).dy,
        closeTo(tester.getCenter(find.byKey(const Key('dial-key-1'))).dy, .01),
      );
    });
    for (final scale in [1.0, 2.0]) {
      for (final size in [const Size(390, 844), const Size(320, 480)]) {
        testWidgets('dial region and pad $platform/$scale/$size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var input = '', models = 0, closes = 0;
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
                  key: const ValueKey('native-dial-render'),
                  child: child!,
                ),
              ),
              home: DialerPage(
                state: const DialerState(name: '不应额外展示'),
                suggestions: const Text(
                  '暂无通话记录',
                  key: Key('native-history-area'),
                ),
                configuration: NativeTranslationDialSummary(
                  model: 'Qwen3.5',
                  languages: '中文 ⇄ 英文',
                  translationEnabled: true,
                  onModel: () => models++,
                  onLanguages: () {},
                ),
                onCountry: () {},
                onDigit: (value) => input += value,
                onDelete: () {},
                onClear: () {},
                onDial: () => fail('No real call'),
                onClose: () => closes++,
              ),
            ),
          );
          expect(find.text('不应额外展示'), findsNothing);
          if (capture && size.height == 844) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('native-dial-render')),
            );
            await tester.runAsync(() async {
              final pixels = await boundary.toImage(pixelRatio: 3);
              final bytes = await pixels.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('.local/ui-reference/dialer-hints-spacing')
                ..createSync(recursive: true);
              File(
                '${dir.path}/${platform.name}-${scale.toInt()}x.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              pixels.dispose();
            });
          }
          if (scale == 1 && size.height == 844) {
            final header = find.byType(NativeDialNumberHeader);
            expect(
              tester
                      .getTopLeft(find.byKey(const Key('native-history-area')))
                      .dy -
                  tester.getBottomLeft(header).dy,
              closeTo(24, .01),
            );
            expect(
              tester.getTopLeft(find.byKey(const Key('dial-key-1'))).dy -
                  tester
                      .getBottomLeft(
                        find.byKey(const Key('translation-model-open')),
                      )
                      .dy,
              closeTo(10, .01),
            );
            expect(
              tester.getTopLeft(find.byKey(const Key('dial-call'))).dy -
                  tester.getBottomLeft(find.byKey(const Key('dial-key-0'))).dy,
              closeTo(12, .01),
            );
          }
          await tester.ensureVisible(
            find.byKey(const Key('translation-model-open')),
          );
          await tester.tap(find.byKey(const Key('translation-model-open')));
          await tester.ensureVisible(find.byKey(const Key('dial-key-9')));
          await tester.tap(find.byKey(const Key('dial-key-9')));
          await tester.tap(find.byKey(const Key('dial-close')));
          expect(input, '9');
          expect(models, 1);
          expect(closes, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
