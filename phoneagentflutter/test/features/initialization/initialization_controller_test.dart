import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/initialization/data/preview_initialization_gateway.dart';
import 'package:phone_agent/features/initialization/presentation/controller/initialization_controller.dart';

void main() {
  for (final scenario in [
    InitializationPreviewScenario.existingIdentity,
    InitializationPreviewScenario.alreadySkipped,
  ]) {
    test('gate skips initialized $scenario without writes', () async {
      final port = PreviewInitializationGateway(scenario);
      final c = InitializationController(port);
      await c.load();
      expect(c.snapshot.finished, true);
      expect(port.writes, isEmpty);
      c.dispose();
    });
  }
  test('load failure is not empty identity and retry works', () async {
    final port = PreviewInitializationGateway(
      InitializationPreviewScenario.loadFailure,
    );
    final c = InitializationController(port);
    await c.load();
    expect(c.snapshot.ready, false);
    expect(c.snapshot.error, isNotEmpty);
    await c.next();
    expect(port.writes, isEmpty);
    await c.load();
    expect(c.snapshot.ready, true);
    c.dispose();
  });
  test(
    'draft back and skip preserve name; disabled model cannot be selected',
    () async {
      final port = PreviewInitializationGateway(
        InitializationPreviewScenario.normal,
      );
      final c = InitializationController(port);
      await c.load();
      await c.next();
      expect(c.snapshot.step, 1);
      c.edit(name: '合成甲', phone: 'abc123456789012');
      c.skipIdentity();
      expect(port.writes, isEmpty);
      expect(c.snapshot.draft.contactPhone, '12345678901');
      c.select('GPT');
      expect(c.snapshot.callModel, 'QWEN_OMNI_PLUS');
      c.back();
      expect(c.snapshot.draft.name, '合成甲');
      c.edit(phone: '');
      await c.next();
      await c.next();
      await c.next();
      expect(c.snapshot.finished, true);
      expect(port.savedIdentity?.name, '合成甲');
      expect(port.skipped, false);
      c.dispose();
    },
  );
  test('call failure does not block completion or repeat mutation', () async {
    final port = PreviewInitializationGateway(
      InitializationPreviewScenario.callFailure,
    );
    final c = InitializationController(port);
    await c.load();
    c.skipIdentity();
    await c.next();
    expect(c.snapshot.finished, true);
    expect(c.snapshot.notice, contains('切换失败'));
    await c.next();
    expect(port.writes, ['call:QWEN_OMNI_PLUS', 'skip']);
    c.dispose();
  });
  test(
    'identity failure retries only failed save retaining call selection',
    () async {
      final port = PreviewInitializationGateway(
        InitializationPreviewScenario.identityFailure,
      );
      final c = InitializationController(port);
      await c.load();
      c.edit(name: '合成乙');
      await c.next();
      await c.next();
      expect(c.snapshot.finished, false);
      expect(c.snapshot.step, 2);
      c.back();
      expect(c.snapshot.draft.name, '合成乙');
      await c.next();
      await c.next();
      expect(port.writes, ['call:QWEN_OMNI_PLUS', 'identity', 'identity']);
      expect(c.snapshot.finished, true);
      c.dispose();
    },
  );
  test(
    'skip stored only at final step and failed local save retries alone',
    () async {
      final port = PreviewInitializationGateway(
        InitializationPreviewScenario.skipFailure,
      );
      final c = InitializationController(port);
      await c.load();
      c.skipIdentity();
      expect(port.skipped, false);
      await c.next();
      expect(c.snapshot.finished, false);
      expect(port.savedIdentity, isNull);
      await c.next();
      expect(port.writes, ['call:QWEN_OMNI_PLUS', 'skip', 'skip']);
      expect(port.skipped, true);
      c.dispose();
    },
  );
  test('delayed model does not block skip and repeated completion', () async {
    final port = _DelayedGateway();
    final c = InitializationController(port);
    await c.load();
    c.skipIdentity();
    final pending = c.next();
    expect(c.snapshot.saving, true);
    c.back();
    c.select('DOUBAO');
    await c.next();
    expect(c.snapshot.step, 2);
    expect(c.snapshot.callModel, 'QWEN_OMNI_PLUS');
    expect(port.requests, 1);
    c.dispose();
    port.completer.complete();
    await pending;
    expect(port.writes, ['skip']);
  });
  test(
    'invalid optional phone cannot submit identity and preserves draft',
    () async {
      final port = PreviewInitializationGateway(
        InitializationPreviewScenario.normal,
      );
      final c = InitializationController(port);
      await c.load();
      c.edit(name: '测试', phone: '12');
      await c.next();
      await c.next();
      await c.next();
      expect(c.snapshot.error, contains('手机号码'));
      expect(c.snapshot.finished, false);
      expect(port.writes, isEmpty);
      c.dispose();
    },
  );
}

class _DelayedGateway extends PreviewInitializationGateway {
  _DelayedGateway() : super(InitializationPreviewScenario.normal);
  final completer = Completer<void>();
  int requests = 0;
  @override
  Future<void> selectCallModel(String id) {
    requests++;
    return completer.future;
  }
}
