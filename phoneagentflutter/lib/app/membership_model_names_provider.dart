import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'business_providers.dart';
import '../features/call_models/domain/call_models.dart';

final membershipModelNamesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      ref.watch(loginEpochProvider);
      final catalog = await ref.watch(callModelRepositoryProvider).load();
      return {
        for (final model in catalog.models)
          model.id: modelName(
            model.provider.isEmpty ? model.id : model.provider,
            model.name,
          ),
      };
    });
