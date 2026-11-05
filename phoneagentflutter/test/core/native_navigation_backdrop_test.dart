import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_navigation_backdrop.dart';

void main() {
  testWidgets(
    'v66 API29 wash matches the native draw and keeps content sharp',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('paint'),
              child: SizedBox(
                width: 320,
                height: 500,
                child: NativeNavigationBackdrop(
                  contentInset: 110,
                  child: CustomPaint(painter: _Stripes()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('paint')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final codec = await ui.instantiateImageCodec(
          File('test/fixtures/navigation_backdrop_android29.png').readAsBytesSync(),
        );
        final frame = await codec.getNextFrame();
        final nativePixels = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        expect(image.width, frame.image.width);
        expect(image.height, frame.image.height);
        var maxChannelDifference = 0;
        for (var i = 0; i < nativePixels.lengthInBytes; i++) {
          final difference = (pixels.getUint8(i) - nativePixels.getUint8(i)).abs();
          if (difference > maxChannelDifference) maxChannelDifference = difference;
        }
        expect(maxChannelDifference, lessThanOrEqualTo(1));
        frame.image.dispose();
        codec.dispose();
        int red(int x, int y) => pixels.getUint8((y * image.width + x) * 4);
        expect((red(81, 100) - red(85, 100)).abs(), 255);
        final reference =
            jsonDecode(
                  File(
                    'test/fixtures/navigation_backdrop_android29.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final sample in reference['samples'] as List) {
          for (var channel = 0; channel < 3; channel++) {
            final actual = pixels.getUint8(
              ((sample[1] as int) * image.width + (sample[0] as int)) * 4 +
                  channel,
            );
            expect(actual, closeTo(sample[2 + channel] as int, 1));
          }
        }
        expect((red(81, 420) - red(85, 420)).abs(), greaterThan(200));
        image.dispose();
      });
      expect(
        tester.getSize(
          find.byKey(const ValueKey('navigation-background-wash')),
        ),
        const Size(320, 154),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final visible in [true, false]) {
    testWidgets('backdrop does not intercept content; visible=$visible', (
      tester,
    ) async {
      var taps = 0;
      double? inset;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeNavigationBackdrop(
              visible: visible,
              contentInset: 133,
              child: Builder(
                builder: (context) {
                  inset = NativeNavigationBackdrop.contentInsetOf(context);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(inset, visible ? 135 : 0);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        find.byKey(const ValueKey('navigation-background-wash')),
        visible ? findsOneWidget : findsNothing,
      );
      await tester.tapAt(const Offset(160, 550));
      expect(taps, 1);
    });
  }
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 4, size.height),
        Paint()..color = (x ~/ 4).isEven ? Colors.black : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
