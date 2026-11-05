import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_management_repository.dart';

const qwen = 'QWEN_OMNI_PLUS', seed = 'DOUBAO_SEEDUPLEX_3_0';
Future<CallModelController> create(
  PreviewCloneManagementRepository repository,
) async {
  final c = CallModelController(
    repository,
    cloneRepository: PreviewCloneManagementPort(repository),
  );
  await c.load();
  await c.loadVoices(qwen);
  return c;
}

void main() {
  test('delete only target asset and read server AI selection', () async {
    final repository = PreviewCloneManagementRepository();
    final c = await create(repository);
    expect(c.state.canDeleteClone, true);
    await c.deleteClone(qwen);
    expect(repository.deleted, [qwen]);
    expect(repository.assets, {seed});
    expect(repository.modes[seed], 'CLONE');
    expect(c.state.voices!.selectionMode, 'AI');
    expect(c.state.clone!.currentReady, false);
    expect(c.state.canDeleteClone, false);
    await c.deleteClone(qwen);
    expect(repository.deleted, [qwen]);
    c.dispose();
  });
  test('candidate hides and blocks current deletion', () async {
    final repository = PreviewCloneManagementRepository(candidate: true);
    final c = await create(repository);
    expect(c.state.canDeleteClone, false);
    await c.deleteClone(qwen);
    expect(repository.deleted, isEmpty);
    c.dispose();
  });
  test(
    'old dialog model cannot delete a different currently visible model',
    () async {
      final repository = PreviewCloneManagementRepository();
      final c = await create(repository);
      await c.loadVoices(seed);
      await c.deleteClone(qwen);
      expect(repository.deleted, isEmpty);
      c.dispose();
    },
  );
  test(
    'unknown delete result blocks replay until explicit read synchronization',
    () async {
      final repository = PreviewCloneManagementRepository(
        failFirstDelete: true,
      );
      final c = await create(repository);
      await c.deleteClone(qwen);
      expect(c.state.cloneNeedsRefresh, true);
      expect(c.state.canDeleteClone, false);
      await c.deleteClone(qwen);
      expect(repository.deleted, [qwen]);
      await c.loadVoices(qwen);
      expect(repository.deleted, [qwen]);
      expect(c.state.canDeleteClone, true);
      await c.deleteClone(qwen);
      expect(repository.deleted, [qwen, qwen]);
      c.dispose();
    },
  );
  test('delete succeeded but failed read retries GET only', () async {
    final repository = PreviewCloneManagementRepository(
      failReadAfterDelete: true,
    );
    final c = await create(repository);
    await c.deleteClone(qwen);
    expect(repository.assets, {seed});
    expect(c.state.cloneNeedsRefresh, true);
    await c.loadVoices(qwen);
    expect(repository.deleted, [qwen]);
    expect(c.state.cloneNeedsRefresh, false);
    expect(c.state.voices!.selectionMode, 'AI');
    c.dispose();
  });
  test('single-flight and disposal ignores late completion', () async {
    final repository = _DelayedRepository();
    final c = await create(repository);
    final operation = c.deleteClone(qwen);
    await c.deleteClone(qwen);
    expect(repository.calls, 1);
    expect(c.state.voiceSaving, true);
    c.dispose();
    repository.completion.complete();
    await operation;
    expect(repository.calls, 1);
  });
}

class _DelayedRepository extends PreviewCloneManagementRepository {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> delete(String provider) async {
    calls++;
    await completion.future;
  }
}
