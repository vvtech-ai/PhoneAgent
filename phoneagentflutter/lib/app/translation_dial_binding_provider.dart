import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'translation_dial_runtime_providers.dart';
import 'domestic_translation_session_providers.dart';

/// Optional entry composition. Production stays unavailable until both media
/// transports are assembled; isolated Web hosts override only their own scope.
final translationDialSessionBindingProvider =
    Provider<TranslationDialSessionBinding?>(
      (ref) {
        final runtime = ref.watch(translationDialRuntimeProvider);
        final domestic = ref.watch(domesticTranslationSessionFactoryProvider);
        return runtime == null && domestic == null
            ? null
            : TranslationDialSessionBinding(
                create:
                    runtime?.create ??
                    (_) => throw StateError('Overseas translation unavailable'),
                createDomestic: domestic?.create,
              );
      },
      dependencies: [
        translationDialRuntimeProvider,
        domesticTranslationSessionFactoryProvider,
      ],
    );
