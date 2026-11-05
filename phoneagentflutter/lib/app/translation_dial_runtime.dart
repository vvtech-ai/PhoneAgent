import 'dart:async';
import '../features/settings/domain/original_audio_settings.dart';
import '../features/translation/domain/translation_backend_session.dart';
import '../features/translation/domain/translation_dial_request.dart';
import '../features/translation/domain/translation_media_port.dart';
import '../features/translation/domain/translation_service_catalog.dart';
import '../features/translation/presentation/controller/translation_session_controller.dart';
import 'translation_session_factory.dart';

/// Both transports are required. Never substitute one transport for the other.
typedef TranslationDeviceMediaFactory =
    TranslationMediaPort Function(
      TranslationMediaTransport transport,
      bool Function() isCurrent,
    );

class TranslationDialServices {
  const TranslationDialServices({
    required this.backend,
    required this.languages,
    required this.close,
  });
  final TranslationBackendRepository backend;
  final Future<TranslationServiceCatalog> Function() languages;
  final void Function() close;
}

/// Account-owned composition. The route owns its controller, this owner keeps
/// HTTP resources alive until late create/hangup have actually finished.
class TranslationDialRuntime {
  TranslationDialRuntime({
    required this.accountId,
    required this.isCurrent,
    required this.sessions,
    required this.media,
    required this.openServices,
    required this.readOriginalAudio,
    this.prepareMedia,
    this.resolveServices,
  });
  final String accountId;
  final bool Function() isCurrent;
  final TranslationSessionFactory sessions;
  final TranslationDeviceMediaFactory media;
  final Future<void> Function()? prepareMedia;
  final TranslationDialServices Function(String region) openServices;
  final Future<TranslationDialServices> Function(TranslationDialRequest)?
  resolveServices;
  final Future<OriginalAudioSettings> Function() readOriginalAudio;
  final _calls = <TranslationSessionController, TranslationDialServices>{};
  bool _closed = false, _preparing = false;
  bool get current => !_closed && accountId.isNotEmpty && isCurrent();
  void _check() {
    if (!current) throw StateError('Translation login expired');
  }

  Future<TranslationSessionController> create(
    TranslationDialRequest dial,
  ) async {
    _check();
    if (_preparing || _calls.isNotEmpty) {
      throw StateError('Translation call already active');
    }
    _preparing = true;
    TranslationDialServices? services;
    try {
      final original = await readOriginalAudio();
      _check();
      final request = dial.toCreateRequest(
        userId: accountId,
        originalAudio: original,
      );
      request.toJson();
      await prepareMedia?.call();
      _check();
      final opened = services = resolveServices == null
          ? openServices(dial.serviceRegion)
          : await resolveServices!(dial);
      _check();
      late final TranslationSessionController controller;
      controller = sessions.create(
        backend: _OwnedBackend(opened.backend, _check),
        mediaFactory: (transport) {
          _check();
          return media(transport, () => current);
        },
        loadLanguages: () async {
          _check();
          final result = await opened.languages();
          _check();
          return result;
        },
        request: request,
        targetName: dial.displayName,
        countryIso: dial.countryIso,
        onReleased: () => _release(controller),
      );
      _calls[controller] = opened;
      return controller;
    } catch (_) {
      services?.close();
      rethrow;
    } finally {
      _preparing = false;
    }
  }

  void _release(TranslationSessionController controller) {
    _calls.remove(controller)?.close();
  }

  Future<void> close() async {
    _closed = true;
    // Provider disposal can happen during a build. Invalidate immediately, then
    // stop UI-observed coordinators outside that synchronous lifecycle.
    await Future<void>.value();
    final calls = _calls.keys.toList();
    await Future.wait(
      calls.map((controller) async {
        await controller.coordinator.stop();
        _release(controller);
      }),
    );
  }
}

/// Reject new business writes after logout but retain the original cleanup path.
class _OwnedBackend implements TranslationBackendRepository {
  const _OwnedBackend(this.delegate, this.check);
  final TranslationBackendRepository delegate;
  final void Function() check;
  @override
  Future<TranslationBackendSession> create(TranslationCreateRequest request) {
    check();
    return delegate.create(request);
  }

  @override
  Future<TranslationMerchantResult> startMerchant(
    TranslationBackendSession session,
    TranslationCreateRequest request,
  ) {
    check();
    return delegate.startMerchant(session, request);
  }

  @override
  Future<void> hangup(TranslationBackendSession session, String userId) =>
      delegate.hangup(session, userId);
}
