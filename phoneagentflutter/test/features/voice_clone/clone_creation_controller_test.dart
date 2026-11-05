import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_creation_controller.dart';

void main() {
  test('unavailable selection preserves the refreshed server reason', () async {
    final port = _Port()
      ..items = [
        const CloneCreationModel(
          cloneEntitled: true,
          id: 'qwen',
          name: 'Qwen',
          available: false,
          unavailableReason: '当前会员不支持该克隆套餐，请查看会员权益',
        ),
      ];
    final controller = CloneCreationController(port);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.select('qwen');
    expect(controller.state.error, port.items.single.unavailableReason);
    expect(controller.state.launch, isNull);
    expect(port.calls, ['models', 'models']);
  });
  Future<CloneCreationController> create(_Port port) async {
    final controller = CloneCreationController(port);
    await controller.load();
    addTearDown(controller.dispose);
    return controller;
  }

  for (final reusable in [true, false]) {
    test(
      'deleted current clone uses fresh recording admission: $reusable',
      () async {
        final port = _Port()
          ..reusable = reusable
          ..items = [
            const CloneCreationModel(
              id: 'qwen',
              name: 'Qwen',
              pricePoints: 300,
              cloneEntitled: true,
              currentReady: true,
            ),
          ];
        final controller = await create(port);
        port.items = [
          const CloneCreationModel(
            id: 'qwen',
            name: 'Qwen',
            pricePoints: 300,
            cloneEntitled: true,
          ),
        ];
        await controller.select('qwen');
        expect(controller.state.confirmReauthentication, isFalse);
        expect(
          controller.state.launch!.start,
          reusable
              ? CloneCreationStart.savedRecording
              : CloneCreationStart.authentication,
        );
      },
    );
  }
  test(
    'changed price updates directory and requires a new explicit selection',
    () async {
      final port = _Port();
      final controller = await create(port);
      port.items = [
        const CloneCreationModel(
          cloneEntitled: true,
          id: 'qwen',
          name: 'Qwen',
          pricePoints: 400,
        ),
      ];
      await controller.select('qwen');
      expect(controller.state.launch, isNull);
      expect(controller.state.models.single.pricePoints, 400);
      expect(controller.state.error, contains('价格已更新'));
      expect(port.calls, ['models', 'models']);
      await controller.select('qwen');
      expect(controller.state.launch!.model.pricePoints, 400);
    },
  );
  test('stale unavailable model can be rechecked without reopening', () async {
    final port = _Port()
      ..items = [
        const CloneCreationModel(
          cloneEntitled: true,
          id: 'qwen',
          name: 'Qwen',
          available: false,
          pricePoints: 300,
        ),
      ];
    final controller = await create(port);
    port.items = [
      const CloneCreationModel(
        cloneEntitled: true,
        id: 'qwen',
        name: 'Qwen',
        pricePoints: 300,
      ),
    ];
    await controller.select('qwen');
    expect(controller.state.launch, isNotNull);
  });
  test(
    'FAILED candidate enters new admission rather than old result',
    () async {
      final port = _Port()
        ..reusable = false
        ..items = [
          const CloneCreationModel(
            cloneEntitled: true,
            id: 'qwen',
            name: 'Qwen',
            pricePoints: 300,
            hasCandidate: true,
            candidateFailed: true,
          ),
        ];
      final controller = await create(port);
      await controller.select('qwen');
      expect(controller.state.launch!.start, CloneCreationStart.authentication);
      expect(port.calls, ['models', 'models', 'points', 'recording']);
    },
  );
  test('refresh failure never admits or reads wallet/recording', () async {
    final port = _Port();
    final controller = await create(port);
    port.catalogFailure = CloneCatalogFailure.network;
    await controller.select('qwen');
    expect(controller.state.launch, isNull);
    expect(controller.state.error, CloneCatalogFailure.network.message);
    expect(port.calls, ['models', 'models']);
  });
  test('rerecord confirmation refreshes and rejects changed price', () async {
    final port = _Port()
      ..items = [
        const CloneCreationModel(
          cloneEntitled: true,
          id: 'qwen',
          name: 'Qwen',
          pricePoints: 300,
          currentReady: true,
        ),
      ];
    final controller = await create(port);
    await controller.select('qwen');
    expect(controller.state.confirmReauthentication, true);
    port.items = [
      const CloneCreationModel(
        cloneEntitled: true,
        id: 'qwen',
        name: 'Qwen',
        pricePoints: 500,
        currentReady: true,
      ),
    ];
    await controller.confirmReauthentication();
    expect(controller.state.confirmReauthentication, false);
    expect(controller.state.launch, isNull);
    expect(controller.state.error, contains('价格已更新'));
    expect(port.calls, ['models', 'models', 'models']);
  });
  test(
    'closing during directory refresh drops late launch and paid checks',
    () async {
      final port = _Port();
      final controller = CloneCreationController(port);
      await controller.load();
      port.pendingCatalog = Completer<List<CloneCreationModel>>();
      final selecting = controller.select('qwen');
      controller.dispose();
      port.pendingCatalog!.complete(port.items);
      await selecting;
      expect(port.calls, ['models', 'models']);
    },
  );
  for (final failure in CloneCatalogFailure.values) {
    test(
      'catalog category is safe and reload does not admit: $failure',
      () async {
        final port = _Port()..catalogFailure = failure;
        final controller = await create(port);
        expect(controller.state.error, failure.message);
        expect(controller.state.models, isEmpty);
        expect(controller.state.launch, isNull);
        port.catalogFailure = null;
        await controller.load();
        expect(controller.state.error, isEmpty);
        expect(controller.state.models, isNotEmpty);
        expect(port.calls, ['models', 'models']);
      },
    );
  }
  for (final reusable in [false, true]) {
    test('new model selects correct recording path: $reusable', () async {
      final port = _Port()..reusable = reusable;
      final controller = await create(port);
      await controller.select('qwen');
      expect(
        controller.state.launch?.start,
        reusable
            ? CloneCreationStart.savedRecording
            : CloneCreationStart.authentication,
      );
      expect(port.calls, ['models', 'models', 'points', 'recording']);
    });
  }
  for (final candidate in [false, true]) {
    test(
      'existing ready asset requires confirmation and never reuse: $candidate',
      () async {
        final port = _Port()
          ..items = [
            CloneCreationModel(
              cloneEntitled: true,
              pricePoints: 300,
              id: 'qwen',
              name: 'Qwen',
              currentReady: !candidate,
              candidateReady: candidate,
            ),
          ];
        final controller = await create(port);
        await controller.select('qwen');
        expect(controller.state.confirmReauthentication, true);
        controller.cancelReauthentication();
        expect(controller.state.launch, isNull);
        expect(port.calls, ['models', 'models']);
        await controller.select('qwen');
        await controller.confirmReauthentication();
        expect(
          controller.state.launch?.start,
          CloneCreationStart.authentication,
        );
        expect(port.calls, ['models', 'models', 'models', 'models', 'points']);
      },
    );
  }
  test('nonready candidate opens without paid entry or new creation', () async {
    final port = _Port()
      ..items = [
        const CloneCreationModel(
          cloneEntitled: true,
          pricePoints: 300,
          id: 'qwen',
          name: 'Qwen',
          hasCandidate: true,
        ),
      ];
    final controller = await create(port);
    await controller.select('qwen');
    expect(
      controller.state.launch?.start,
      CloneCreationStart.existingCandidate,
    );
    expect(port.calls, ['models', 'models']);
  });
  test('unavailable known models refresh without paid side effects', () async {
    final port = _Port()
      ..items = [
        const CloneCreationModel(
          cloneEntitled: true,
          pricePoints: 300,
          id: 'qwen',
          name: 'Qwen',
          available: false,
        ),
      ];
    final controller = await create(port);
    await controller.select('qwen');
    await controller.select('other');
    expect(controller.state.launch, isNull);
    expect(port.calls, ['models', 'models']);
  });
  test(
    '299 blocked, 300 allowed, wallet failure never becomes zero/success',
    () async {
      final port = _Port()..points = 299;
      final controller = await create(port);
      await controller.select('qwen');
      expect(controller.state.error, contains('积分不足'));
      expect(port.calls, ['models', 'models', 'points']);
      port.walletError = true;
      await controller.select('qwen');
      expect(controller.state.launch, isNull);
      expect(controller.state.error, contains('暂时无法'));
      port.walletError = false;
      port.points = 300;
      await controller.select('qwen');
      expect(controller.state.launch, isNotNull);
    },
  );
  test(
    'loading failure retries explicitly, empty catalog remains empty',
    () async {
      final port = _Port()..loadError = true;
      final controller = await create(port);
      expect(
        controller.state.error,
        CloneCatalogFailure.serviceUnavailable.message,
      );
      port.loadError = false;
      port.items = [];
      await controller.load();
      expect(controller.state.models, isEmpty);
      expect(controller.state.error, isEmpty);
    },
  );
  test(
    'single flight and disposal prevent late recording read/navigation',
    () async {
      final port = _Port()..pending = Completer<int>();
      final controller = CloneCreationController(port);
      await controller.load();
      final first = controller.select('qwen');
      await controller.select('qwen');
      await Future<void>.delayed(Duration.zero);
      expect(port.calls, ['models', 'models', 'points']);
      controller.dispose();
      port.pending!.complete(900);
      await first;
      expect(port.calls, ['models', 'models', 'points']);
    },
  );
}

class _Port implements CloneCreationPort {
  final calls = <String>[];
  List<CloneCreationModel> items = [
    const CloneCreationModel(
      cloneEntitled: true,
      pricePoints: 300,
      id: 'qwen',
      name: 'Qwen',
    ),
  ];
  CloneCatalogFailure? catalogFailure;
  int points = 900;
  bool reusable = true, loadError = false, walletError = false;
  Completer<int>? pending;
  Completer<List<CloneCreationModel>>? pendingCatalog;
  @override
  Future<List<CloneCreationModel>> models() async {
    calls.add('models');
    if (catalogFailure != null) throw catalogFailure!;
    if (loadError) throw StateError('load');
    return pendingCatalog == null ? items : pendingCatalog!.future;
  }

  @override
  Future<int> availablePoints() async {
    calls.add('points');
    if (walletError) throw StateError('wallet');
    return pending == null ? points : pending!.future;
  }

  @override
  Future<bool> hasValidRecording() async {
    calls.add('recording');
    return reusable;
  }
}
