import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dialer/domain/dial_country.dart';
import '../../domain/translation_preferences.dart';
import '../../domain/translation_directory.dart';
import '../../domain/translation_preference_store.dart';
import '../../domain/translation_language_policy.dart';
import '../../domain/translation_model_selection.dart';

class TranslationSetupState {
  const TranslationSetupState({
    this.value = const TranslationPreferences(),
    this.ready = false,
    this.loading = false,
    this.saving = false,
    this.error = '',
  });
  final TranslationPreferences value;
  final bool ready, loading, saving;
  final String error;
}

class TranslationSetupController extends StateNotifier<TranslationSetupState> {
  TranslationSetupController({TranslationPreferenceStore? store})
    : _store = store,
      super(
        TranslationSetupState(
          value: store == null
              ? const TranslationPreferences()
              : const TranslationPreferences(caller: '', peer: ''),
          ready: store == null,
        ),
      );
  final TranslationPreferenceStore? _store;
  TranslationDirectory? _directory;
  String? _callerCountryIso;
  bool? _overseas;
  bool _callerDefaultPending = true;
  List<TranslationLanguage> get languages {
    if (_directory == null) return translationLanguages;
    final configured = [
      for (final item in _directory!.languages)
        TranslationLanguage(
          item.code,
          item.name.isEmpty || item.name == item.code
              ? translationLanguage(item.code).label
              : item.name,
          item.name.isEmpty || item.name == item.code
              ? translationLanguage(item.code).nativeLabel
              : item.name,
        ),
    ];
    final codes = configured.map((item) => item.code).toSet();
    final backendDefaults = {
      if (_directory!.defaultCaller.isNotEmpty) _directory!.defaultCaller,
      for (final country in _directory!.countries)
        if (country.defaultLanguage.isNotEmpty) country.defaultLanguage,
    };
    return [
      ...configured,
      for (final item in translationLanguages)
        if (backendDefaults.contains(item.code) && codes.add(item.code)) item,
      for (final code in backendDefaults)
        if (codes.add(code)) TranslationLanguage(code, code, code),
    ];
  }

  List<DialCountry> get countries => _directory == null
      ? dialCountries
      : [
          for (final item in _directory!.countries)
            DialCountry(
              item.iso,
              item.name,
              item.dialCode,
              dialCountry(item.iso)?.pinyin ?? item.iso,
              dialCountry(item.iso)?.initials ?? item.iso,
            ),
        ];
  void directory(
    TranslationDirectory? value, {
    String? callerCountryIso,
    bool? overseas,
  }) {
    _directory = value;
    if (callerCountryIso != null) {
      _callerCountryIso = callerCountryIso.toUpperCase();
    }
    if (overseas != null) _overseas = overseas;
    if (!_editable || value == null) return;
    final next = _normalize(snapshot);
    if (_callerCountryIso?.isNotEmpty == true) _callerDefaultPending = false;
    if (!_same(next, snapshot)) _change(next);
  }

  TranslationDirectoryModel? _selectedModel(TranslationPreferences value) {
    final directory = _directory;
    if (directory == null) return null;
    if (_callerCountryIso?.isNotEmpty == true) {
      return selectTranslationModel(
        directory,
        value,
        _callerCountryIso,
        forced: _overseas == true && _callerCountryIso == 'CN',
      );
    }
    return directory.model(
      _overseas == false ? value.domesticModelId : value.overseasModelId,
    );
  }

  TranslationPreferences _normalize(
    TranslationPreferences value, {
    TranslationDirectoryModel? model,
  }) {
    model ??= _selectedModel(value);
    final pair = normalizeTranslationLanguages(
      enabledCodes: languages.map((item) => item.code),
      caller: _callerDefaultPending && _callerCountryIso?.isNotEmpty == true
          ? ''
          : value.caller,
      peer: value.peer,
      defaultCaller:
          _directory?.country(_callerCountryIso ?? '')?.defaultLanguage ??
          _directory?.defaultCaller ??
          '',
      defaultPeer: _directory?.country(value.country)?.defaultLanguage ?? '',
      sourceCodes: model == null || model.sourceLanguages.isEmpty
          ? null
          : model.sourceLanguages.toSet(),
      targetCodes: model == null || model.targetLanguages.isEmpty
          ? null
          : model.targetLanguages.toSet(),
    );
    final caller =
        _callerDefaultPending &&
            _callerCountryIso?.isNotEmpty != true &&
            value.caller.isEmpty
        ? ''
        : pair.caller;
    return value.copy(caller: caller, peer: pair.peer);
  }

  bool _same(TranslationPreferences a, TranslationPreferences b) =>
      a.enabled == b.enabled &&
      a.prompt == b.prompt &&
      a.caller == b.caller &&
      a.peer == b.peer &&
      a.normalCountry == b.normalCountry &&
      a.translationCountry == b.translationCountry &&
      a.provider == b.provider &&
      a.domesticModelId == b.domesticModelId &&
      a.overseasModelId == b.overseasModelId &&
      a.region == b.region &&
      a.forceBackend == b.forceBackend &&
      a.simulatedCountryIso == b.simulatedCountryIso;

  int _revision = 0;
  bool _writing = false;
  TranslationPreferences get snapshot => state.value;
  TranslationSetupState get status => state;
  bool get _editable => mounted && state.ready;

  Future<void> load() async {
    if (!mounted || state.loading || state.ready) return;
    state = const TranslationSetupState(loading: true);
    try {
      final value = await _store!.read();
      if (mounted) {
        _callerDefaultPending = value.caller.isEmpty;
        state = TranslationSetupState(value: value, ready: true);
        if (_directory != null) directory(_directory);
      }
    } catch (_) {
      if (mounted) {
        state = const TranslationSetupState(error: '读取翻译配置失败，请重试');
      }
    }
  }

  void _change(TranslationPreferences value) {
    if (!_editable) return;
    _revision++;
    state = TranslationSetupState(
      value: value,
      ready: true,
      saving: _store != null,
    );
    if (_store != null) save();
  }

  Future<void> save() async {
    if (!_editable || _writing || _store == null) return;
    _writing = true;
    state = TranslationSetupState(value: snapshot, ready: true, saving: true);
    try {
      while (mounted) {
        final version = _revision, value = snapshot;
        await _store.write(value);
        if (!mounted) return;
        if (version == _revision) {
          state = TranslationSetupState(value: value, ready: true);
          return;
        }
      }
    } catch (_) {
      if (mounted) {
        state = TranslationSetupState(
          value: snapshot,
          ready: true,
          error: '翻译配置尚未保存，请重试',
        );
      }
    } finally {
      _writing = false;
    }
  }

  void simulateCountry(String iso) {
    final normalized = iso.trim().toUpperCase();
    if (!_editable ||
        (normalized.isNotEmpty &&
            !RegExp(r'^[A-Z]{2}$').hasMatch(normalized))) {
      return;
    }
    _change(
      snapshot.copy(simulatedCountryIso: normalized, forceBackend: false),
    );
  }

  void enable(bool value) {
    if (_editable) _change(snapshot.copy(enabled: value));
  }

  void prompt(bool value) {
    if (_editable) _change(snapshot.copy(prompt: value));
  }

  void language(
    String code, {
    required bool caller,
    Set<String>? supportedCodes,
  }) {
    if (!_editable ||
        !snapshot.enabled ||
        !languages.any((item) => item.code == code) ||
        supportedCodes != null && !supportedCodes.contains(code)) {
      return;
    }
    if (caller) _callerDefaultPending = false;
    _change(caller ? snapshot.copy(caller: code) : snapshot.copy(peer: code));
  }

  void country(
    String iso, {
    bool syncPeer = true,
    Set<String>? supportedPeerCodes,
  }) {
    if (!_editable || !countries.any((c) => c.iso == iso)) return;
    final peer = !syncPeer && snapshot.peer.isNotEmpty
        ? snapshot.peer
        : _defaultPeerLanguage(iso, supportedCodes: supportedPeerCodes);
    final next = snapshot.enabled
        ? snapshot.copy(translationCountry: iso, peer: peer)
        : snapshot.copy(normalCountry: iso, peer: peer);
    _change(_selectedModel(next) == null ? next : _normalize(next));
  }

  String _defaultPeerLanguage(String iso, {Set<String>? supportedCodes}) {
    final configured = _directory?.country(iso)?.defaultLanguage ?? '';
    if (configured.isNotEmpty &&
        languages.any(
          (item) =>
              item.code == configured &&
              (supportedCodes == null || supportedCodes.contains(item.code)),
        )) {
      return configured;
    }
    return languages
            .where(
              (item) =>
                  supportedCodes == null || supportedCodes.contains(item.code),
            )
            .firstOrNull
            ?.code ??
        '';
  }

  void provider(String id) {
    if (_editable && const ['OPENAI', 'GEMINI', 'QWEN'].contains(id)) {
      _change(snapshot.copy(provider: id));
    }
  }

  void selectModel(String id, String engine, {required bool overseas}) {
    final model = _directory?.model(id);
    if (!_editable || model == null) return;
    _overseas = overseas;
    _change(
      _normalize(
        overseas
            ? snapshot.copy(overseasModelId: id, provider: engine)
            : snapshot.copy(domesticModelId: id),
        model: model,
      ),
    );
  }

  /// History restores the caller; the number country always determines peer.
  void restoreHistory({
    required String countryIso,
    required String callerLanguage,
    String peerLanguage = '',
    Set<String>? supportedPeerCodes,
  }) {
    if (!_editable) return;
    final iso =
        countries
            .where((item) => item.iso == countryIso.toUpperCase())
            .firstOrNull
            ?.iso ??
        snapshot.country;
    final caller = languages.any((item) => item.code == callerLanguage)
        ? callerLanguage
        : snapshot.caller;
    final peer = _defaultPeerLanguage(iso, supportedCodes: supportedPeerCodes);
    if (callerLanguage == caller && caller.isNotEmpty) {
      _callerDefaultPending = false;
    }
    final next = snapshot.enabled
        ? snapshot.copy(translationCountry: iso, caller: caller, peer: peer)
        : snapshot.copy(normalCountry: iso, caller: caller, peer: peer);
    _change(_selectedModel(next) == null ? next : _normalize(next));
  }

  void region(String id) {
    if (_editable && const ['DEFAULT', 'US', 'JP'].contains(id)) {
      _change(snapshot.copy(region: id));
    }
  }

  void forceBackend(bool enabled) {
    if (_editable) _change(snapshot.copy(forceBackend: enabled));
  }
}
