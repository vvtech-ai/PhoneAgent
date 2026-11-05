part of 'translation_dialer_route.dart';

/// Dial admission and confirmations, separate from the page layout.
extension _TranslationDialerActions on _TranslationDialerRouteState {
  void _showDialNotice(String message) {
    if (_current) {
      showNativeNotice(context, message, duration: const Duration(seconds: 2));
    }
  }

  String get _invalidNumberMessage =>
      _dial.countryIso == 'CN' ? '请输入正确的手机号码' : '请输入正确的电话号码';

  Future<void> _call(
    ValueChanged<bool> requestEnable,
    bool Function() canProceed, {
    bool presetsConfirmed = false,
  }) async {
    if (!_editable) return;
    if (_setup.snapshot.enabled && !widget.preview) {
      recordTranslationLocationPreflight(ref, _setup.snapshot);
    }
    if (_setup.snapshot.enabled &&
        !widget.preview &&
        ref.read(translationAccessProvider).loading) {
      return;
    }
    final recent = ref.read(dialRecentProvider).records;
    if (_dial.input.isEmpty && recent.isNotEmpty) {
      _restoreRecent(recent.first);
      return;
    }
    if (_dial.input == '20142014*#') {
      await _dialer.dial();
      return;
    }
    _update(() => _opening = true);
    try {
      if (!presetsConfirmed &&
          _setup.snapshot.enabled &&
          _setup.snapshot.prompt &&
          !await showTranslationPresets(
            context,
            _setup,
            requestEnable,
            callerLanguageCodes: _supportedLanguageCodes(caller: true),
            peerLanguageCodes: _supportedLanguageCodes(caller: false),
          )) {
        return;
      }
      if (!mounted || !_current || !canProceed()) return;
      if (_setup.snapshot.enabled) {
        final callerLanguage = _setup.snapshot.caller;
        final peerLanguage = _setup.snapshot.peer;
        if (callerLanguage.isEmpty || peerLanguage.isEmpty) {
          _showDialNotice('请选择我方和对方语种');
          return;
        }
        if (callerLanguage == peerLanguage) {
          _showDialNotice('请选择不同的我方和对方语种');
          return;
        }
      }
      final options = widget.preview
          ? null
          : ref.read(translationDirectoryProvider).valueOrNull;
      final needsWarning = translationPhoneNeedsWarning(
        _dial.input,
        _dial.country,
        options?.country(_dial.countryIso),
      );
      final allowUnverifiedNumber =
          needsWarning &&
          await confirmTranslationPhoneFormat(
            context,
            isCurrent: () => _current && canProceed(),
            readSnapshot: () => _confirmationSnapshot,
          );
      if (!mounted ||
          !_current ||
          !canProceed() ||
          (needsWarning && !allowUnverifiedNumber)) {
        return;
      }
      if (DialPhonePolicy.resolveForCall(
            _dial.input,
            _dial.countryIso,
            configuredCountry: _dial.country,
            allowUnverifiedNumber: allowUnverifiedNumber,
          ) ==
          null) {
        _showDialNotice(_invalidNumberMessage);
        return;
      }
      // Never fall back to ordinary dialing when the user requested translation.
      if (_setup.snapshot.enabled) {
        if (!await allowOnlineEntry(context) ||
            !mounted ||
            !_current ||
            !canProceed()) {
          return;
        }
        final access = widget.preview
            ? const TranslationAccess(countryIso: 'US', forced: false)
            : ref.read(translationAccessProvider);
        if (access.countryIso == null || access.loading) {
          _showDialNotice('主叫所在国家尚未确认');
          return;
        }
        final binding =
            widget.sessionBinding ??
            (widget.preview
                ? null
                : ref.read(translationDialSessionBindingProvider));
        if (binding == null) {
          _showDialNotice('当前环境无法发起实时翻译通话，请在已登录的手机 App 中使用');
          return;
        }
        final model = widget.preview
            ? null
            : ref.read(selectedTranslationModelProvider);
        if (!widget.preview && model == null) {
          _showDialNotice('当前没有可用的实时翻译模型');
          return;
        }
        final callerLanguage = _setup.snapshot.caller;
        final peerLanguage = _setup.snapshot.peer;
        if (model != null && !model.supports(callerLanguage, peerLanguage)) {
          _showDialNotice('当前模型不支持所选的我方与对方语种互译');
          return;
        }
        final domestic = !widget.preview && model?.transport == 'LOCAL_SIP';
        if (!await confirmCrossBorderTranslationCall(
          context,
          callerCountryIso: access.countryIso,
          calleeCountryIso: _dial.countryIso,
          isCurrent: () => _current && canProceed(),
          readSnapshot: () => _confirmationSnapshot,
        )) {
          return;
        }
        final request = domestic
            ? null
            : TranslationDialRequest(
                allowUnverifiedNumber: allowUnverifiedNumber,
                callerCountryIso: access.countryIso ?? '',
                rawNumber: _dial.input,
                countryIso: _dial.countryIso,
                configuredCountry: _dial.country,
                displayName: _dial.name,
                modelId: model?.id ?? '',
                preferences: model == null
                    ? _setup.snapshot
                    : _setup.snapshot.copy(provider: model.engine),
              );
        final targetLabel =
            request?.targetLabel ??
            (_dial.name.isEmpty ? _dial.input : _dial.name);
        final controller = domestic
            ? await createDomesticTranslationDial(
                ref,
                binding,
                allowUnverifiedNumber: allowUnverifiedNumber,
                rawNumber: _dial.input,
                countryIso: _dial.countryIso,
                configuredCountry: _dial.country,
                displayName: _dial.name,
                preferences: model == null
                    ? _setup.snapshot
                    : _setup.snapshot.copy(provider: model.engine),
              )
            : await binding.create(request!);
        if (!mounted || !_current || !canProceed()) {
          controller.dispose();
          return;
        }
        final container = ProviderScope.containerOf(context);
        await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => RouteProviderScope(
              container: container,
              child: TranslationSessionRoute(
                target: targetLabel,
                createController: () => controller,
                headerBuilder: binding.header,
              ),
            ),
          ),
        );
      } else {
        await _dialer.dial(allowUnverifiedNumber: allowUnverifiedNumber);
      }
    } on TranslationPlanFailure catch (failure) {
      if (_current) {
        _showDialNotice(switch (failure.code) {
          'LOCATION_UNAVAILABLE' => '主叫所在国家尚未确认',
          'INVALID_NUMBER' => _invalidNumberMessage,
          'NETWORK_UNAVAILABLE' || 'NETWORK_VALIDATION_TIMEOUT' =>
            translationCallFailureMessage('NETWORK'),
          _ => failure.message,
        });
      }
    } on SipLeaseFailure catch (failure) {
      if (_current) {
        _showDialNotice(translationCallFailureMessage(failure.code));
      }
    } on TranslationDialPreflightFailure {
      if (_current) {
        _showDialNotice('请授予麦克风权限后再使用实时翻译通话');
      }
    } catch (_) {
      if (_current) _showDialNotice(translationCallFailureMessage('UNKNOWN'));
    } finally {
      if (mounted) _update(() => _opening = false);
    }
  }

  Future<void> _presetsCall(
    ValueChanged<bool> enable,
    bool Function() ready,
  ) async {
    if (!_editable) return;
    final confirmed = await showTranslationPresets(
      context,
      _setup,
      enable,
      callerLanguageCodes: _supportedLanguageCodes(caller: true),
      peerLanguageCodes: _supportedLanguageCodes(caller: false),
    );
    if (_current && confirmed) {
      await _call(enable, ready, presetsConfirmed: true);
    }
  }

  Set<String>? _supportedLanguageCodes({required bool caller}) {
    if (widget.preview) return null;
    final model = ref.read(selectedTranslationModelProvider);
    final codes = caller ? model?.sourceLanguages : model?.targetLanguages;
    if (codes == null || codes.isEmpty) return null;
    return codes.toSet();
  }
}
