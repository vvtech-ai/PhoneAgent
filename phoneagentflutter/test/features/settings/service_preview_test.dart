import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/controller/service_preview_controller.dart';

void main() {
  test(
    'log compression/upload single flight, fail/retry/success are synthetic',
    () async {
      final c = ServicePreviewController(
        PreviewService.logs,
        step: Duration.zero,
      );
      addTearDown(c.dispose);
      c.failNext = true;
      final pending = c.run();
      expect(c.snapshot.phase, ServicePreviewPhase.compressing);
      await c.run();
      await pending;
      expect(c.snapshot.phase, ServicePreviewPhase.failed);
      await c.run();
      expect(c.snapshot.phase, ServicePreviewPhase.success);
    },
  );
  test('OTA latest, available, failed checksum, ready and handoff', () async {
    final c = ServicePreviewController(
      PreviewService.update,
      step: Duration.zero,
    );
    addTearDown(c.dispose);
    c.latest = true;
    await c.run();
    expect(c.snapshot.phase, ServicePreviewPhase.latest);
    c.latest = false;
    c.failNext = true;
    await c.run();
    expect(c.snapshot.phase, ServicePreviewPhase.available);
    expect(c.failNext, isTrue);
    c.handoff();
    expect(c.snapshot.phase, ServicePreviewPhase.available);
    await c.run();
    expect(c.snapshot.phase, ServicePreviewPhase.failed);
    c.handoff();
    expect(c.snapshot.phase, ServicePreviewPhase.failed);
    await c.run();
    expect(c.snapshot.phase, ServicePreviewPhase.ready);
    c.handoff();
    expect(c.snapshot.phase, ServicePreviewPhase.handoff);
  });
  test('closing preview while busy is safe', () async {
    final c = ServicePreviewController(
      PreviewService.logs,
      step: Duration.zero,
    );
    final pending = c.run();
    c.dispose();
    await pending;
  });
}
