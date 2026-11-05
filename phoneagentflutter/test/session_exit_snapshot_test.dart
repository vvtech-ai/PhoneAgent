import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/session_exit_snapshot.dart';

Future<ui.Image> frame() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFF00FF00), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final result = await picture.toImage(4, 4);
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('clear and disposal release the accepted image', () async {
    var ready = 0;
    final snapshot = SessionExitSnapshot(
      onReady: () {
        ready++;
      },
    );
    final image = await frame();
    snapshot.begin(() async => image);
    await Future<void>.delayed(Duration.zero);
    expect(snapshot.image, same(image));
    expect(ready, 1);
    snapshot.clear();
    expect(image.debugDisposed, isTrue);
    expect(snapshot.image, isNull);
    snapshot.dispose();
  });
  test('late frame from old owner is disposed, never displayed', () async {
    var ready = 0;
    final snapshot = SessionExitSnapshot(
      onReady: () {
        ready++;
      },
    );
    final pending = Completer<ui.Image?>();
    snapshot.begin(() => pending.future);
    snapshot.clear();
    final image = await frame();
    pending.complete(image);
    await Future<void>.delayed(Duration.zero);
    expect(ready, 0);
    expect(image.debugDisposed, isTrue);
    snapshot.dispose();
  });
  test(
    'capture failure and timeout retain fallback without waiting for late frame',
    () async {
      var ready = 0;
      final snapshot = SessionExitSnapshot(
        onReady: () {
          ready++;
        },
        timeout: const Duration(milliseconds: 1),
      );
      snapshot.begin(() async => throw StateError('synthetic capture failure'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(snapshot.image, isNull);
      final pending = Completer<ui.Image?>();
      snapshot.begin(() => pending.future);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final image = await frame();
      pending.complete(image);
      await Future<void>.delayed(Duration.zero);
      expect(ready, 0);
      expect(image.debugDisposed, isTrue);
      snapshot.dispose();
    },
  );
  test('disposal invalidates and releases an in-flight result', () async {
    var ready = 0;
    final snapshot = SessionExitSnapshot(
      onReady: () {
        ready++;
      },
    );
    final pending = Completer<ui.Image?>();
    snapshot.begin(() => pending.future);
    snapshot.dispose();
    final image = await frame();
    pending.complete(image);
    await Future<void>.delayed(Duration.zero);
    expect(ready, 0);
    expect(image.debugDisposed, isTrue);
  });
}
