import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/support_feedback/domain/feedback.dart';
import 'package:phone_agent/features/support_feedback/presentation/feedback_controller.dart';
import 'package:phone_agent/core/diagnostics/device_environment.dart';
import 'package:phone_agent/features/app_logs/domain/format_device_environment.dart';

class Logs implements AppLogRepository {
  Logs({DeviceEnvironment? environment})
    : bundle = AppLogBundle(
        watermark: 7,
        count: 1,
        bytes: Uint8List.fromList([1, 2]),
        fileName: 'logs.zip',
        environment: environment,
      );
  int prepared = 0, acknowledged = 0;
  bool cleanupFails = false;
  final AppLogBundle bundle;
  @override
  Future<AppLogBundle> prepare() async {
    prepared++;
    return bundle;
  }

  @override
  Future<void> acknowledge(AppLogBundle bundle) async {
    if (cleanupFails) throw StateError('disk');
    acknowledged++;
  }

  @override
  Future<void> upload(AppLogBundle bundle) =>
      throw StateError('legacy upload forbidden');
}

class Gateway implements FeedbackGateway {
  bool fail = false;
  final requests = <FeedbackRequest>[];
  Completer<void>? pending;
  @override
  Future<void> submit(FeedbackRequest request) async {
    requests.add(request);
    await pending?.future;
    if (fail) throw StateError('network');
  }
}

void main() {
  late Logs logs;
  late Gateway gateway;
  late FeedbackController controller;
  var current = true;
  setUp(() {
    logs = Logs();
    gateway = Gateway();
    current = true;
    controller = FeedbackController(
      gateway: gateway,
      logs: logs,
      current: () => current,
      deviceInfo: () async => 'device',
    );
  });
  tearDown(() => controller.dispose());
  test(
    'feedback reuses the device snapshot already captured in its diagnostic ZIP',
    () async {
      const environment = DeviceEnvironment(
        appVersion: '1.8.0',
        appBuild: 60,
        osName: 'iOS',
        osVersion: '18.0',
        brand: 'Apple',
        manufacturer: 'Apple',
        model: 'iPhone',
        hardwareModel: 'iPhone17,3',
      );
      final capturedLogs = Logs(environment: environment);
      controller.dispose();
      controller = FeedbackController(
        gateway: gateway,
        logs: capturedLogs,
        current: () => true,
        deviceInfo: () async =>
            throw StateError('must not reread device metadata'),
      );
      controller.edit(description: '问题', includeLogs: true);
      await controller.submit();
      expect(controller.snapshot.success, isTrue);
      expect(
        gateway.requests.single.deviceInfo,
        formatDeviceEnvironment(environment),
      );
      expect(gateway.requests.single.logs, same(capturedLogs.bundle));
    },
  );
  test(
    'codepoint validation preserves contact and rejects blank description',
    () async {
      controller.edit(description: ' \n');
      await controller.submit();
      expect(gateway.requests, isEmpty);
      controller.edit(description: '😀' * 2000, contact: ' 001\n微信 ');
      await controller.submit();
      expect(gateway.requests.single.description.runes.length, 2000);
      expect(gateway.requests.single.contact, ' 001\n微信 ');
      expect(logs.prepared, 0);
    },
  );
  test(
    'failed whole submission retains snapshot and request identity on retry',
    () async {
      controller.edit(description: '问题', includeLogs: true);
      gateway.fail = true;
      await controller.submit();
      expect(controller.snapshot.success, isFalse);
      expect(controller.snapshot.description, '问题');
      expect(logs.acknowledged, 0);
      gateway.fail = false;
      await controller.submit();
      expect(identical(gateway.requests[0], gateway.requests[1]), isTrue);
      expect(logs.prepared, 1);
      expect(logs.acknowledged, 1);
      expect(controller.snapshot.success, isTrue);
    },
  );
  test(
    'editing after failure allocates a different immutable request',
    () async {
      controller.edit(description: '旧问题');
      gateway.fail = true;
      await controller.submit();
      controller.edit(description: '新问题');
      gateway.fail = false;
      await controller.submit();
      expect(
        gateway.requests[0].requestId,
        isNot(gateway.requests[1].requestId),
      );
    },
  );
  test('cleanup failure never resubmits the accepted feedback', () async {
    controller.edit(description: '问题', includeLogs: true);
    logs.cleanupFails = true;
    await controller.submit();
    expect(controller.snapshot.success, isTrue);
    logs.cleanupFails = false;
    await controller.submit();
    expect(gateway.requests.length, 1);
    expect(logs.acknowledged, 1);
  });
  test('account changes during preparation prevent upload', () async {
    controller = FeedbackController(
      gateway: gateway,
      logs: logs,
      current: () => current,
      deviceInfo: () async {
        current = false;
        return '';
      },
    );
    controller.edit(description: '问题', includeLogs: true);
    await controller.submit();
    expect(gateway.requests, isEmpty);
    expect(logs.acknowledged, 0);
  });
  test(
    'repeated tap during submission does not create duplicate request',
    () async {
      gateway.pending = Completer<void>();
      controller.edit(description: '问题');
      final first = controller.submit();
      await Future<void>.delayed(Duration.zero);
      await controller.submit();
      expect(gateway.requests.length, 1);
      gateway.pending!.complete();
      await first;
    },
  );
  test(
    'unicode length boundaries reject oversized input without losing it',
    () async {
      controller.edit(description: '😀' * 2001);
      await controller.submit();
      expect(controller.snapshot.description.runes.length, 2001);
      expect(gateway.requests, isEmpty);
      controller.edit(description: '问题', contact: '😀' * 201);
      await controller.submit();
      expect(gateway.requests, isEmpty);
      controller.edit(contact: '😀' * 200);
      await controller.submit();
      expect(gateway.requests.single.contact.runes.length, 200);
    },
  );
  test(
    'image processing blocks submission and failure never sends the original',
    () async {
      controller.edit(description: '问题');
      final pending = Completer<List<FeedbackImage>>();
      final operation = controller.addImages((_) => pending.future);
      expect(controller.snapshot.processing, isTrue);
      await controller.submit();
      expect(gateway.requests, isEmpty);
      pending.completeError(const FormatException('图片处理失败'));
      await operation;
      expect(controller.snapshot.images, isEmpty);
      expect(controller.snapshot.busy, isFalse);
      expect(controller.snapshot.error, '图片处理失败');
    },
  );
  test(
    'six prepared images survive failure and a seventh cannot be added',
    () async {
      controller.edit(description: '问题');
      final images = List.generate(
        6,
        (i) => FeedbackImage(Uint8List.fromList([i]), 'i$i.png', 'image/png'),
      );
      await controller.addImages((remaining) async {
        expect(remaining, 6);
        return images;
      });
      var picked = false;
      await controller.addImages((_) async {
        picked = true;
        return [];
      });
      expect(picked, isFalse);
      gateway.fail = true;
      await controller.submit();
      expect(controller.snapshot.images.length, 6);
      expect(gateway.requests.single.images.map((i) => i.bytes.single), [
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
    },
  );
  test(
    'account changes during pending upload only acknowledge captured logs',
    () async {
      controller.edit(description: '问题', includeLogs: true);
      gateway.pending = Completer<void>();
      final operation = controller.submit();
      await Future<void>.delayed(Duration.zero);
      current = false;
      gateway.pending!.complete();
      await operation;
      expect(logs.acknowledged, 1);
      expect(controller.snapshot.success, isFalse);
      expect(gateway.requests.length, 1);
    },
  );
  test('optional device metadata cannot block feedback without logs', () async {
    controller.dispose();
    controller = FeedbackController(
      gateway: gateway,
      logs: logs,
      current: () => current,
      deviceInfo: () async => throw StateError('metadata unavailable'),
    );
    controller.edit(description: '问题');
    await controller.submit();
    expect(gateway.requests.single.deviceInfo, '');
    expect(controller.snapshot.success, isTrue);
  });
}
