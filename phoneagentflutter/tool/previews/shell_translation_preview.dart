import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/dial_permission_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_catalog_providers.dart';
import 'package:phone_agent/app/translation_dial_binding_provider.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/preview_translation_configuration.dart';
import 'package:phone_agent/features/translation/data/preview_translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_completion_preview_controller.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_session_preview_controls.dart';

final shellTranslationCompletionProvider =
    Provider<TranslationCompletionPreviewController>(
      (_) => throw StateError('Only available inside the MOCK shell'),
      dependencies: [],
    );

/// One workbench's synthetic settings and external ports, never production DI.
class ShellTranslationPreviewPorts {
  ShellTranslationPreviewPorts({required this.originalAudio});
  final OriginalAudioSettings Function() originalAudio;
  final preferences = PreviewTranslationPreferenceStore()
    ..value = const TranslationPreferences(translationCountry: 'US');
  final location = PreviewTranslationLocation()
    ..cached = TrustedTranslationLocation('US', 1);
  final billing = PreviewTranslationBilling();
  final permissions = PreviewDialPermissionPort(supportsCallLog: false)
    ..grant = DialPermissionGrant.granted;
  final permissionMemory = DialPermissionMemory()..locationShown = true;

  List<Override> get overrides => [
    translationDirectoryProvider.overrideWith(
      (ref) async => previewTranslationDirectory,
    ),
    dialPermissionPortProvider.overrideWithValue(permissions),
    dialPermissionMemoryProvider.overrideWithValue(permissionMemory),
    shellTranslationCompletionProvider.overrideWith((ref) {
      ref.watch(loginEpochProvider);
      final preview = TranslationCompletionPreviewController();
      ref.onDispose(preview.dispose);
      return preview;
    }),
    translationDialSessionBindingProvider.overrideWith((ref) {
      final preview = ref.watch(shellTranslationCompletionProvider);
      return TranslationDialSessionBinding(
        create: (request) {
          preview.originalAudio = originalAudio();
          return preview.createDial(request);
        },
        header: (_, controller) => TranslationSessionPreviewControls(
          fixture: preview.activeFixture!,
          state: controller.snapshot,
        ),
      );
    }),
    appCallRecordRepositoryProvider.overrideWith(
      (ref) => ref.watch(shellTranslationCompletionProvider).store.repository,
    ),
    systemDialRecentSourceProvider.overrideWithValue(
      const UnavailableDialRecentSource(DialRecentAccess.unsupported),
    ),
    translationPreferenceStoreProvider.overrideWithValue(preferences),
    translationLocationSourceProvider.overrideWithValue(location),
    translationLocationStoreProvider.overrideWithValue(location),
    translationBillingRepositoryProvider.overrideWithValue(billing),
    translationCatalogRepositoryProvider.overrideWithValue(
      const PreviewTranslationCatalog(),
    ),
    translationModelQualityProvider.overrideWith(
      (_, region) async => {
        'OPENAI': TranslationModelSample.reachable(140),
        'GEMINI': TranslationModelSample.reachable(620),
      },
    ),
  ];
}
