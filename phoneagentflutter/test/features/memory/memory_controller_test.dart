import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/controller/memory_controller.dart';
import 'package:phone_agent/features/memory/data/api_memory_repository.dart';

MemorySnapshot snapshot(bool enabled) => MemorySnapshot(
  enabled: enabled,
  entries: [],
  skills: [],
  usedCharacters: 0,
  maxCharacters: 3000,
  maxEntries: 30,
);

class Repository implements MemoryRepository {
  Completer<MemorySnapshot>? pending;
  int calls = 0;
  @override
  Future<MemorySnapshot> load() async => snapshot(false);
  @override
  Future<MemorySnapshot> apply(MemoryAction action) {
    calls++;
    return pending!.future;
  }
}

void main() {
  test(
    'switch is immediate, failure rolls back, operations cannot overlap',
    () async {
      final repo = Repository()..pending = Completer();
      final c = MemoryController(repo, isCurrent: () => true);
      addTearDown(c.dispose);
      await c.load();
      final pending = c.apply(const MemoryAction('SET_ENABLED', enabled: true));
      expect(c.state.snapshot!.enabled, isTrue);
      expect(await c.apply(const MemoryAction('CLEAR')), isFalse);
      expect(repo.calls, 1);
      repo.pending!.completeError(StateError('network'));
      expect(await pending, isFalse);
      expect(c.state.snapshot!.enabled, isFalse);
      expect(c.state.error, isNotEmpty);
    },
  );
  test('old account mutation response cannot be accepted', () async {
    var current = true;
    final repo = Repository()..pending = Completer();
    final c = MemoryController(repo, isCurrent: () => current);
    addTearDown(c.dispose);
    await c.load();
    final pending = c.apply(const MemoryAction('CLEAR'));
    current = false;
    repo.pending!.complete(snapshot(true));
    expect(await pending, isFalse);
    expect(c.state.snapshot!.enabled, isFalse);
  });
  test('malformed memory response never becomes an empty successful page', () {
    expect(
      () => ApiMemoryRepository.parse({'enabled': true}),
      throwsA(anything),
    );
    final dto = {
      'enabled': true,
      'entries': [],
      'skills': [],
      'usedCharacters': 0,
      'maxCharacters': 3000,
      'maxEntries': 30,
    };
    expect(ApiMemoryRepository.parse(dto).enabled, isTrue);
    expect(
      () => ApiMemoryRepository.parse({...dto, 'maxCharacters': 0}),
      throwsA(anything),
    );
  });
}
