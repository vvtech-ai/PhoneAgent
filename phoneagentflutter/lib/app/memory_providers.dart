import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/memory/data/api_memory_repository.dart';
import '../features/memory/domain/account_memory.dart';
import '../features/memory/presentation/controller/memory_controller.dart';
import 'business_providers.dart';

final memoryRepositoryProvider = Provider.autoDispose<MemoryRepository>(
  (ref) => ApiMemoryRepository(ref.watch(accountApiProvider)),
);
final memoryControllerProvider =
    StateNotifierProvider.autoDispose<MemoryController, MemoryState>((ref) {
      final epoch = ref.watch(loginEpochProvider);
      var closed = false;
      ref.onDispose(() => closed = true);
      final controller = MemoryController(
        ref.watch(memoryRepositoryProvider),
        isCurrent: () =>
            !closed && epoch != null && ref.read(loginEpochProvider) == epoch,
      );
      controller.load();
      return controller;
    });
