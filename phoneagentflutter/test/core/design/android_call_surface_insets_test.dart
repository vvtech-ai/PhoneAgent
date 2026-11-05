import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'android_call_navigation_background_test.dart' show callPage;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final translation in [false, true]) {
      for (final bottom in [0.0, 24.0, 48.0]) {
        testWidgets(
          '$platform translation=$translation inset=$bottom background and content',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(390, 844);
            tester.view.padding = FakeViewPadding(bottom: bottom);
            final modes = <MethodCall>[];
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              (call) async {
                if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) {
                  modes.add(call);
                }
                return null;
              },
            );
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                SystemChannels.platform,
                null,
              );
              tester.view.reset();
            });
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    backgroundColor: Colors.white,
                    body: callPage(translation),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.text('内容由AI生成')).bottom,
              closeTo(844 - bottom - 20, .1),
            );
            if (platform == TargetPlatform.iOS) {
              expect(modes, isEmpty);
            } else {
              expect(modes.last.arguments, 'SystemUiMode.edgeToEdge');
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final color = await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final data = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                final offset =
                    ((image.height - 1) * image.width + image.width ~/ 2) * 4;
                final pixel = Color.fromARGB(
                  data.getUint8(offset + 3),
                  data.getUint8(offset),
                  data.getUint8(offset + 1),
                  data.getUint8(offset + 2),
                );
                image.dispose();
                return pixel;
              });
              final expected = translation
                  ? const Color(0xFF1A2C52)
                  : const Color(0xFF0B0D12);
              expect(color!.r, closeTo(expected.r, 2 / 255));
              expect(color.g, closeTo(expected.g, 2 / 255));
              expect(color.b, closeTo(expected.b, 2 / 255));
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
