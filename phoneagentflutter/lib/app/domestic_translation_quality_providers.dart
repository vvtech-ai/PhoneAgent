import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/api_translation_runtime.dart';
import '../features/translation/data/runtime_translation_model_probe.dart';
import '../features/translation/domain/translation_model_quality.dart';
import 'business_providers.dart';
import 'translation_directory_providers.dart';
import 'translation_access_providers.dart';

final domesticTranslationModelProbeProvider =
    Provider.autoDispose<TranslationModelProbe>((ref) {
      ref.watch(loginEpochProvider);
      final country = ref.watch(translationAccessProvider).countryIso;
      final probe = RuntimeTranslationModelProbe(
        ApiTranslationRuntime(ref.watch(accountApiProvider)),
        country ?? '',
      );
      ref.onDispose(probe.close);
      return probe;
    });

final domesticTranslationModelQualityProvider =
    FutureProvider.autoDispose<Map<String, TranslationModelSample>>((
      ref,
    ) async {
      final epoch = ref.watch(loginEpochProvider);
      final access = ref.watch(translationAccessProvider);
      if (epoch == null || access.loading || access.countryIso == null) {
        return const {};
      }
      final probe = ref.watch(domesticTranslationModelProbeProvider);
      Future<TranslationModelSample> sample(String model) async {
        try {
          return await probe.sample(model);
        } catch (_) {
          return const TranslationModelSample.unavailable();
        }
      }

      final directory = await ref.watch(translationDirectoryProvider.future);
      final ids =
          directory
              .country(access.countryIso!)
              ?.modelIds
              .where(
                (id) =>
                    directory.model(id)?.transport == 'LOCAL_SIP' &&
                    const {
                      'QWEN',
                      'DOUBAO',
                    }.contains(directory.model(id)?.engine),
              )
              .toList() ??
          <String>[];
      final samples = await Future.wait(ids.map(sample));
      return {for (var i = 0; i < ids.length; i++) ids[i]: samples[i]};
    });
