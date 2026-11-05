import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';

const allowed = CallModel(
  id: '1',
  name: 'one',
  description: '',
  available: true,
  active: true,
);
const denied = CallModel(
  id: '1',
  name: 'one',
  description: '',
  available: false,
  active: true,
);
const availableCatalog = CallModelCatalog('1', [allowed]);

class Directory implements CallModelRepository {
  final reads = <Completer<CallModelCatalog>>[];
  int writes = 0;
  int voiceWrites = 0;
  Completer<CallModelCatalog>? write;
  @override
  Future<CallModelCatalog> load() {
    final result = Completer<CallModelCatalog>();
    reads.add(result);
    return result.future;
  }

  @override
  Future<CallModelCatalog> select(String id) async {
    writes++;
    return write?.future ?? CallModelCatalog(id, [allowed]);
  }

  @override
  Future<CallVoiceCatalog> loadVoices(String id) async =>
      const CallVoiceCatalog('v1', 'AI', [CallVoice('v2', 'two', '', false)]);
  @override
  Future<CallVoiceCatalog> selectVoice(String id, String voice) async {
    voiceWrites++;
    throw StateError('Unexpected stale write');
  }
}

void main() {
  test('refresh prevents stale voice writes while pending or denied', () async {
    final repository = Directory();
    final controller = CallModelController(repository);
    addTearDown(controller.dispose);
    final initial = controller.load();
    repository.reads.single.complete(availableCatalog);
    await initial;
    await controller.loadVoices('1');
    final voice = controller.state.voices!.voices.single;
    final refresh = controller.load();
    await controller.selectVoice(voice);
    expect(repository.voiceWrites, 0);
    repository.reads.last.complete(const CallModelCatalog('', [denied]));
    await refresh;
    await controller.selectVoice(voice);
    expect(repository.voiceWrites, 0);
  });
  test('latest refresh wins over an in-flight pre-upgrade directory', () async {
    final repository = Directory();
    final controller = CallModelController(repository);
    addTearDown(controller.dispose);
    final old = controller.load();
    final fresh = controller.load();
    expect(repository.reads, hasLength(2));
    repository.reads[1].complete(availableCatalog);
    await fresh;
    repository.reads[0].complete(const CallModelCatalog('1', [denied]));
    await old;
    expect(controller.state.catalog?.current?.available, isTrue);
  });

  test(
    'refresh and failure cannot authorize retained old model objects',
    () async {
      final repository = Directory();
      final controller = CallModelController(repository);
      addTearDown(controller.dispose);
      final initial = controller.load();
      repository.reads.single.complete(availableCatalog);
      await initial;
      final refresh = controller.load();
      expect(controller.state.catalog, isNull);
      expect(await controller.select(allowed), isFalse);
      repository.reads.last.completeError(StateError('network'));
      await refresh;
      expect(controller.state.catalog, isNull);
      expect(await controller.select(allowed), isFalse);
      expect(repository.writes, 0);
    },
  );

  test('unavailable active marker never produces a current model', () {
    expect(const CallModelCatalog('1', [denied]).current, isNull);
  });

  test(
    'refresh during a manual save reconciles before reporting success',
    () async {
      final repository = Directory();
      final controller = CallModelController(repository);
      addTearDown(controller.dispose);
      final initial = controller.load();
      repository.reads.single.complete(
        const CallModelCatalog('other', [allowed]),
      );
      await initial;
      repository.write = Completer<CallModelCatalog>();
      final save = controller.select(allowed);
      await controller.load();
      expect(controller.state.catalog, isNull);
      expect(controller.state.loading, isTrue);
      repository.write!.complete(availableCatalog);
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, hasLength(2));
      repository.reads.last.complete(const CallModelCatalog('', [denied]));
      expect(await save, isFalse);
      expect(controller.state.catalog?.current, isNull);
    },
  );

  test('a stale available instance cannot bypass a refreshed denial', () async {
    final repository = Directory();
    final controller = CallModelController(repository);
    addTearDown(controller.dispose);
    final read = controller.load();
    repository.reads.single.complete(const CallModelCatalog('', [denied]));
    await read;
    expect(await controller.select(allowed), isFalse);
    expect(repository.writes, 0);
  });
}
