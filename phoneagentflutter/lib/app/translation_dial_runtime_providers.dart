import 'diagnostics_providers.dart';
import '../features/translation/data/api_translation_directory.dart';
import 'translation_access_providers.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/translation/data/http_translation_backend_repository.dart';
import '../features/translation/data/http_translation_catalog_repository.dart';
import '../features/translation/domain/translation_dial_preflight.dart';
import 'agent_context_providers.dart';
import 'translation_device_media_providers.dart';
import 'business_providers.dart';
import 'settings_providers.dart';
import 'translation_catalog_providers.dart';
import 'translation_dial_runtime.dart';
import 'translation_finished_providers.dart';

export 'translation_device_media_providers.dart'
    show translationDeviceMediaFactoryProvider;

final translationDialRuntimeProvider = Provider<TranslationDialRuntime?>(
  (ref) {
    final media = ref.watch(translationDeviceMediaFactoryProvider);
    if (kIsWeb || media == null) return null;
    ref.watch(loginEpochProvider);
    final session = ref.watch(sessionControllerProvider.notifier);
    final owner = session.credentials;
    if (owner == null) return null;
    final endpoint = ref.watch(translationEndpointProvider);
    final factory = ref.watch(translationSessionFactoryProvider);
    ref.watch(originalAudioControllerProvider.notifier);
    final store = ref.watch(originalAudioStoreProvider);
    final permissions = ref.watch(conversationPermissionSourceProvider);
    var active = true;
    bool current() => active && owner.sameLogin(session.credentials);
    final runtime = TranslationDialRuntime(
      accountId: owner.accountId,
      isCurrent: current,
      sessions: factory,
      media: media,
      prepareMedia: () => ensureTranslationMicrophone(permissions, current),
      readOriginalAudio: () async {
        final loaded = ref.read(originalAudioControllerProvider);
        if (loaded.ready) return loaded.value;
        final value = await store.read();
        if (!current()) throw StateError('Translation login expired');
        // A concurrent settings edit is newer than the just-finished storage read.
        final latest = ref.read(originalAudioControllerProvider);
        return latest.ready ? latest.value : value;
      },
      resolveServices: (dial) async {
        final directory = await ApiTranslationDirectory(
          ref.read(accountApiProvider),
        ).load();
        if (!current()) throw StateError('Translation login expired');
        final location = ref.read(translationAccessProvider);
        final country = directory.country(
          dial.callerCountryIso.isEmpty
              ? location.countryIso ?? ''
              : dial.callerCountryIso,
        );
        final model = dial.modelId.isEmpty
            ? directory.engine(dial.preferences.provider)
            : directory.model(dial.modelId);
        final callee = directory.country(dial.countryIso);
        if (callee == null ||
            (!dial.allowUnverifiedNumber && !callee.acceptsPhone(dial.phone)) ||
            country == null ||
            model == null ||
            !country.modelIds.contains(model.id) ||
            model.transport != 'BACKEND_WEBRTC' ||
            model.engine != dial.preferences.provider ||
            !model.supports(dial.preferences.caller, dial.preferences.peer)) {
          throw StateError('当前国家、模型或语言配置不可用，请重新选择');
        }
        // Match the active Android legacy gateway, which resolves deployment
        // by service region rather than the directory's future node binding.
        final base = endpoint(dial.serviceRegion);
        final backend = HttpTranslationBackendRepository(
          base,
          diagnostics: ref.read(diagnosticJournalProvider).record,
        );
        final catalog = HttpTranslationCatalogRepository(
          (_) => base,
          diagnostics: ref.read(diagnosticJournalProvider).record,
        );
        return TranslationDialServices(
          backend: backend,
          languages: () => catalog.load(dial.serviceRegion),
          close: () {
            catalog.close();
            backend.close();
          },
        );
      },
      openServices: (region) {
        final base = endpoint(region);
        final backend = HttpTranslationBackendRepository(
          base,
          diagnostics: ref.read(diagnosticJournalProvider).record,
        );
        final catalog = HttpTranslationCatalogRepository(
          (_) => base,
          diagnostics: ref.read(diagnosticJournalProvider).record,
        );
        return TranslationDialServices(
          backend: backend,
          languages: () => catalog.load(region),
          close: () {
            catalog.close();
            backend.close();
          },
        );
      },
    );
    ref.onDispose(() {
      active = false;
      unawaited(runtime.close());
    });
    return runtime;
  },
  dependencies: [
    translationDeviceMediaFactoryProvider,
    conversationPermissionSourceProvider,
  ],
);
