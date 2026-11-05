import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/presentation/widgets/native_update_dialog.dart';

const capture = String.fromEnvironment('OTA_ACTIONS_CAPTURE');
const primary = Key('ota-render-primary'), later = Key('ota-render-later');
const boundary = Key('ota-render-boundary');

void main() {
  setUpAll(() async {
    if (capture.isEmpty) return;
    final bytes = await File('C:/Windows/Fonts/msyh.ttc').readAsBytes();
    for (final family in ['Roboto', 'Ahem']) {
      final font = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await font.load();
    }
  });
  for (final options in [
    (320.0, 1.0, 1.0),
    (393.0, 2.75, 1.0),
    (320.0, 3.0, 2.0),
  ]) {
    testWidgets('OTA actions stay within rounded bounds at $options', (
      tester,
    ) async {
      final (width, dpr, scale) = options;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(width * dpr, 680 * dpr);
      addTearDown(tester.view.reset);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: capture.isEmpty ? null : 'Roboto'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFF777777),
              body: NativeUpdateDialog(
                title: '发现新版本',
                version: '1.0.52',
                notes: '测试新包',
                primary: scale > 1 ? '重新下载并安装' : '立即更新',
                primaryKey: primary,
                laterKey: later,
                onPrimary: () => calls++,
                onLater: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final left = tester.getRect(find.byKey(later));
      final right = tester.getRect(find.byKey(primary));
      expect(left.width, closeTo(right.width, .01));
      expect(left.height, closeTo(right.height, .01));
      expect(right.left - left.right, closeTo(12, .01));
      expect(right.right, lessThan(width));
      final gesture = await tester.startGesture(right.center);
      await tester.pump(const Duration(milliseconds: 150));
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final image = (await tester.runAsync(
        () => render.toImage(pixelRatio: dpr),
      ))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(bytes, isNotNull);
      // Ink, gradients and antialiasing must leave the centre gap white.
      for (
        var y = (left.top * dpr).ceil();
        y < (left.bottom * dpr).floor();
        y++
      ) {
        for (
          var x = ((left.right + 2) * dpr).ceil();
          x < ((right.left - 2) * dpr).floor();
          x++
        ) {
          final index = (y * image.width + x) * 4;
          expect(bytes!.buffer.asUint8List(index, 4), [255, 255, 255, 255]);
        }
      }
      if (capture.isNotEmpty) {
        final png = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        final directory = Directory(capture)..createSync(recursive: true);
        File(
          '${directory.path}/ota-${width.toInt()}-$dpr-$scale.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      }
      image.dispose();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('force update keeps one full-width action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NativeUpdateDialog(
          title: '发现重要版本更新',
          version: '1.0.52',
          notes: '',
          force: true,
          primary: '立即更新',
          primaryKey: primary,
          laterKey: later,
          onPrimary: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(later), findsNothing);
    expect(find.byKey(primary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
