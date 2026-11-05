import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';

void main() {
  const capture = bool.fromEnvironment('VOICE_INK_CAPTURE');
  setUpAll(() async {
    if (!capture) return;
    const font = String.fromEnvironment('VOICE_INK_ICON_FONT');
    if (font.isEmpty) throw StateError('Capture requires explicit icon font');
    final loader = FontLoader('MaterialIcons')
      ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform preview feedback stays inside visible circle', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      var previews = 0, selections = 0;
      Future<void> show({
        bool loading = false,
        bool playing = false,
        bool enabled = true,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: Material(
                  color: Colors.white,
                  child: SizedBox(
                    width: 280,
                    height: 67,
                    child: NativeVoiceSelectionRow(
                      voice: const CallVoice('sample', 'sample', '', false),
                      selected: false,
                      enabled: true,
                      onSelect: () => selections++,
                      showPreview: true,
                      previewLoading: loading,
                      previewPlaying: playing,
                      onPreview: enabled ? () => previews++ : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<ui.Image> raster(String state) async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        return tester
            .runAsync(() async {
              final image = await boundary.toImage();
              if (capture) {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  '.local/ui-reference/voice-preview-ink/'
                  '${platform.name}-$state.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
              }
              return image;
            })
            .then((value) => value!);
      }

      Future<Color> pixel(ui.Image image, Offset point) async {
        final data = await tester.runAsync(() => image.toByteData());
        final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        final bytes = data!.buffer.asUint8List();
        return Color.fromARGB(
          bytes[index + 3],
          bytes[index],
          bytes[index + 1],
          bytes[index + 2],
        );
      }

      await show();
      final icon = find.byIcon(Icons.play_arrow);
      final origin = tester.getTopLeft(find.byKey(boundaryKey));
      final center = tester.getCenter(icon) - origin;
      final outside = center + const Offset(-23, 0);
      final inside = center + const Offset(-15, 0);
      final idle = await raster('idle');
      expect(await pixel(idle, outside), Colors.white);
      final idleInside = await pixel(idle, inside);
      idle.dispose();
      final press = await tester.startGesture(center + origin);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      final pressed = await raster('pressed');
      expect(
        await pixel(pressed, outside),
        Colors.white,
        reason: '48px hit target must not paint ink outside 38px circle',
      );
      expect(await pixel(pressed, inside), isNot(idleInside));
      pressed.dispose();
      await press.up();
      await tester.pumpAndSettle();
      expect([previews, selections], [1, 0]);
      final released = await raster('released');
      expect(await pixel(released, outside), Colors.white);
      expect(await pixel(released, inside), idleInside);
      released.dispose();
      final canceled = await tester.startGesture(center + origin);
      await tester.pump(const Duration(milliseconds: 150));
      await canceled.cancel();
      await tester.pumpAndSettle();
      expect(previews, 1);
      final canceledImage = await raster('canceled');
      expect(await pixel(canceledImage, inside), idleInside);
      canceledImage.dispose();
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(center + origin);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect([previews, selections], [4, 0]);
      await show(loading: true);
      expect(
        tester.getCenter(find.byType(CircularProgressIndicator)),
        center + origin,
      );
      (await raster('loading')).dispose();
      await show(playing: true);
      expect(tester.getCenter(find.byIcon(Icons.stop)), center + origin);
      (await raster('playing')).dispose();
      await show(enabled: false);
      await tester.tapAt(center + origin);
      await tester.pumpAndSettle();
      expect([previews, selections], [4, 0]);
      (await raster('disabled')).dispose();
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform large scrolling cancels preview without selecting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var previews = 0, selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                children: [
                  for (var i = 0; i < 16; i++)
                    NativeVoiceSelectionRow(
                      key: ValueKey('row-$i'),
                      voice: CallVoice(
                        'voice-$i',
                        'Voice $i',
                        'description',
                        false,
                      ),
                      selected: false,
                      enabled: true,
                      onSelect: () => selections++,
                      showPreview: true,
                      onPreview: () => previews++,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.descendant(
        of: find.byKey(const ValueKey('row-0')),
        matching: find.byIcon(Icons.play_arrow),
      );
      final gesture = await tester.startGesture(tester.getCenter(first));
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveBy(const Offset(0, -180));
      await gesture.up();
      await tester.pumpAndSettle();
      expect([previews, selections], [0, 0]);
      final last = find.byKey(const ValueKey('row-15'));
      await tester.scrollUntilVisible(last, 200);
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: last, matching: find.byIcon(Icons.play_arrow)),
      );
      await tester.pumpAndSettle();
      expect([previews, selections], [1, 0]);
      expect(tester.takeException(), isNull);
    });
  }
}
