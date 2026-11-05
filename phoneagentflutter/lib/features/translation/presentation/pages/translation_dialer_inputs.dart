part of 'translation_dialer_route.dart';

/// Number restoration and one-shot feedback, independent of dial admission.
extension _TranslationDialerInputs on _TranslationDialerRouteState {
  TranslationDirectory? get _numberDirectory => widget.preview
      ? null
      : ref.read(translationDirectoryProvider).valueOrNull;

  void _observeDial(DialerState state) {
    _dial = state;
    if (state.message.isNotEmpty &&
        (!widget.preview || _setup.snapshot.enabled)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_current || _dial.message != state.message) return;
        _showDialNotice(state.message);
        _dialer.consumeMessage(state.message);
      });
    }
    if (mounted) _update(() {});
  }

  void _syncLocationContext(TranslationAccess access) {
    Future.microtask(() {
      if (!_input.current(ref) || !mounted || widget.preview) return;
      _setup.directory(
        ref.read(translationDirectoryProvider).valueOrNull,
        callerCountryIso: access.countryIso ?? '',
        overseas: access.countryIso != 'CN' || access.forced,
      );
    });
  }

  void _restoreDialer() {
    if (!_input.current(ref)) return;
    _input.applyEntryMode(_setup, current: () => _current);
    if (_prepared) {
      _setCountry(_setup.snapshot.country);
      return;
    }
    if (widget.number != null && !widget.preview) {
      final options = ref.read(translationDirectoryProvider);
      if (options.isLoading) {
        return;
      }
      _entryNeedsDirectory = options.valueOrNull == null;
    }
    _prepared = true;
    _setCountry(_setup.snapshot.country);
    if (widget.number != null) {
      if (widget.countryIso != null) _setCountry(widget.countryIso!);
      _dialer.prepare(
        widget.number!,
        name: widget.name,
        directory: _numberDirectory,
      );
      final iso = _dial.countryIso;
      final valid = _dial.message.isEmpty;
      // Provider changes must run after widget initialization, including when
      // the country was already selected but its peer language was changed.
      Future.microtask(() {
        if (_current && valid) {
          _setup.country(
            iso,
            supportedPeerCodes: _supportedLanguageCodes(caller: false),
          );
        }
      });
    }
  }

  void _setCountry(String iso) => _dialer.country(
    iso,
    configuredCountry: _setup.countries.where((c) => c.iso == iso).firstOrNull,
  );

  void _restoreContact(String phone, String name) {
    if (!_editable) return;
    _entryEdited = true;
    _dialer.prepare(phone, name: name, directory: _numberDirectory);
    if (_dial.name == name && _dial.message.isEmpty) {
      _setup.country(
        _dial.countryIso,
        supportedPeerCodes: _supportedLanguageCodes(caller: false),
      );
    }
  }

  void _restoreRecent(DialRecentCall record) {
    if (!_editable) return;
    _entryEdited = true;
    if (_dialer.restoreRecent(record, directory: _numberDirectory)) {
      _setup.restoreHistory(
        countryIso: _dial.countryIso,
        callerLanguage: record.callerLanguage,
        supportedPeerCodes: _supportedLanguageCodes(caller: false),
      );
    }
  }
}
