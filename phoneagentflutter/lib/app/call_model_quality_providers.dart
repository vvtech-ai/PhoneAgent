import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/call_models/data/api_call_model_quality_repository.dart';
import '../features/call_models/domain/call_model_quality.dart';
import '../features/call_models/presentation/controller/call_model_quality_controller.dart';
import 'business_providers.dart';

final callModelQualityRepositoryProvider =
    Provider.autoDispose<CallModelQualityRepository>(
      (ref) => ApiCallModelQualityRepository(ref.watch(accountApiProvider)),
    );
final callModelQualityProvider =
    StateNotifierProvider.autoDispose<
      CallModelQualityController,
      CallModelQualityState
    >((ref) {
      ref.watch(loginEpochProvider);
      return CallModelQualityController(
        ref.watch(callModelQualityRepositoryProvider),
      );
    });
