import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/app_logs/presentation/controller/log_report_controller.dart';

void main() {
  test(
    'native entry uploads one batch, blocks duplicates and retries cleanup only',
    () async {
      final port = _Port()
        ..pending = Completer<void>()
        ..hasMore = true
        ..cleanupFail = true;
      final controller = LogReportController(port);
      addTearDown(controller.dispose);
      final first = controller.submitFromEntry();
      await Future<void>.delayed(Duration.zero);
      await controller.submitFromEntry();
      expect(port.prepares, 1);
      expect(port.uploads, 1);
      port.pending!.complete();
      await first;
      expect(controller.snapshot.phase, LogReportPhase.cleanupFailed);
      port.cleanupFail = false;
      await controller.submitFromEntry();
      expect(port.uploads, 1);
      expect(port.acks, 2);
      expect(port.prepares, 1);
      await controller.submitFromEntry();
      expect(port.prepares, 2);
      expect(port.uploads, 2);
    },
  );

  test(
    'next batch requires completed cleanup and another explicit upload',
    () async {
      final port = _Port()..hasMore = true;
      final c = LogReportController(port);
      addTearDown(c.dispose);
      await c.prepare();
      await c.prepareNext();
      expect(port.prepares, 1);
      await c.upload();
      expect(port.uploads, 1);
      expect(port.prepares, 1);
      await c.prepareNext();
      expect(port.prepares, 2);
      expect(port.uploads, 1);
      port.hasMore = false;
      await c.upload();
      expect(port.uploads, 2);
    },
  );
  test('cleanup failure blocks moving to next batch', () async {
    final port = _Port()
      ..hasMore = true
      ..cleanupFail = true;
    final c = LogReportController(port);
    addTearDown(c.dispose);
    await c.prepare();
    await c.upload();
    await c.prepareNext();
    expect(port.prepares, 1);
    expect(port.uploads, 1);
    port.cleanupFail = false;
    await c.retryCleanup();
    await c.prepareNext();
    expect(port.prepares, 2);
    expect(port.uploads, 1);
  });
  test('prepare never uploads and success acknowledges once', () async {
    final port = _Port();
    final c = LogReportController(port);
    addTearDown(c.dispose);
    await c.prepare();
    expect(port.uploads, 0);
    expect(c.snapshot.phase, LogReportPhase.ready);
    await c.upload();
    await c.upload();
    expect(port.uploads, 1);
    expect(port.acks, 1);
    expect(c.snapshot.phase, LogReportPhase.success);
  });
  test(
    'failed upload retains bundle and never clears until explicit retry succeeds',
    () async {
      final port = _Port()..fail = true;
      final c = LogReportController(port);
      addTearDown(c.dispose);
      await c.prepare();
      await c.upload();
      expect(c.snapshot.phase, LogReportPhase.failed);
      expect(port.acks, 0);
      port.fail = false;
      await c.upload();
      expect(port.uploads, 2);
      expect(port.acks, 1);
    },
  );
  test('cleanup failure retries only cleanup, never POST', () async {
    final port = _Port()..cleanupFail = true;
    final c = LogReportController(port);
    addTearDown(c.dispose);
    await c.prepare();
    await c.upload();
    expect(c.snapshot.phase, LogReportPhase.cleanupFailed);
    await c.upload();
    await c.prepare();
    port.cleanupFail = false;
    await c.retryCleanup();
    expect(port.uploads, 1);
    expect(port.acks, 2);
    expect(c.snapshot.phase, LogReportPhase.success);
  });
  test(
    'duplicate upload blocked and disposal permits captured snapshot cleanup',
    () async {
      final port = _Port()..pending = Completer<void>();
      final c = LogReportController(port);
      await c.prepare();
      final upload = c.upload();
      await c.upload();
      expect(port.uploads, 1);
      c.dispose();
      port.pending!.complete();
      await upload;
      expect(port.acks, 1);
    },
  );
  test('prepare failure is not empty success', () async {
    final port = _Port()..prepareFail = true;
    final c = LogReportController(port);
    addTearDown(c.dispose);
    await c.prepare();
    await c.upload();
    expect(c.snapshot.phase, LogReportPhase.failed);
    expect(port.uploads, 0);
    port.prepareFail = false;
    await c.prepare();
    expect(c.snapshot.phase, LogReportPhase.ready);
  });
}

class _Port implements AppLogRepository {
  int uploads = 0, acks = 0, prepares = 0;
  bool hasMore = false;
  bool fail = false, cleanupFail = false, prepareFail = false;
  Completer<void>? pending;
  @override
  Future<AppLogBundle> prepare() async {
    prepares++;
    if (prepareFail) throw StateError('prepare');
    return AppLogBundle(
      watermark: 1,
      count: 1,
      bytes: Uint8List.fromList([1]),
      fileName: 'synthetic.zip',
      hasMore: hasMore,
    );
  }

  @override
  Future<void> upload(AppLogBundle bundle) async {
    uploads++;
    if (fail) throw StateError('upload');
    await pending?.future;
  }

  @override
  Future<void> acknowledge(AppLogBundle bundle) async {
    acks++;
    if (cleanupFail) throw StateError('cleanup');
  }
}
