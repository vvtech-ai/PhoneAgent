import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const capture = bool.fromEnvironment('UI_PREFLIGHT_CAPTURE');
  setUpAll(() async {
    if (!capture) return;
    for (final entry in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      if (entry.value.isEmpty) {
        throw StateError('Capture requires explicit local fonts');
      }
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('isolated preflight render $platform/$scale', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: platform,
              fontFamily: capture ? 'ReferenceText' : null,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: key,
              child: TranslationCallPage(
                state: const TranslationCallView(),
                target: '+1 202 555 0101',
                controls: TranslationCallControls(
                  state: const TranslationCallView(),
                  onMute: () {},
                  onSpeaker: () {},
                  onPad: () {},
                  onDigit: (_) {},
                  onHangup: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('正在检测通话环境'), findsOneWidget);
        expect(find.text('取消通话准备'), findsNothing);
        expect(find.byType(Card), findsNothing);
        expect(tester.takeException(), isNull);
        if (capture) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final raster = await boundary.toImage(pixelRatio: 3);
            final bytes = await raster.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '.local/ui-reference/preflight-native-flow/${platform.name}-${scale.toInt()}x.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            raster.dispose();
          });
        }
      });
    }
  }
}
