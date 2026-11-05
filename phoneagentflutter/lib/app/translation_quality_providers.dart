import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/backend_translation_model_probe.dart';
import '../features/translation/domain/translation_model_quality.dart';
import '../features/translation/data/api_translation_directory.dart';
import 'business_providers.dart';
import 'translation_access_providers.dart';

final translationModelProbeProvider =
    Provider.autoDispose<TranslationModelProbe>((ref) {
      ref.watch(loginEpochProvider);
      final api = ref.watch(accountApiProvider);
      final country = ref.watch(translationAccessProvider).countryIso;
      final probe = BackendTranslationModelProbe(() async {
        final directory = await ApiTranslationDirectory(api).load();
        final node = directory.country(country ?? '')?.nodeEndpoint ?? '';
        if (node.isEmpty) throw StateError('Node unavailable');
        final uri = Uri.parse(node);
        return uri.replace(
          path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/',
        );
      });
      ref.onDispose(probe.close);
      return probe;
    });

final translationModelQualityProvider = FutureProvider.autoDispose
    .family<Map<String, TranslationModelSample>, String>((ref, region) async {
      final probe = ref.watch(translationModelProbeProvider);
      Future<TranslationModelSample> sample(String model) async {
        try {
          return await probe.sample(model);
        } catch (_) {
          return const TranslationModelSample.unavailable();
        }
      }

      final results = await Future.wait([
        sample('OPENAI'),
        sample('GEMINI'),
        sample('QWEN'),
      ]);
      return {'OPENAI': results[0], 'GEMINI': results[1], 'QWEN': results[2]};
    });
