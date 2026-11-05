import '../../../../core/design/native_notice.dart';
import '../../domain/translation_call_failure.dart';
import '../widgets/cross_border_translation_confirmation.dart';
import '../widgets/translation_phone_format_confirmation.dart';
import '../../../../app/business_providers.dart' show loginEpochProvider;
import '../../../../app/translation_location_diagnostics.dart';
import '../../../../app/translation_directory_providers.dart';
import '../../../../app/translation_model_selection_providers.dart';
import 'package:flutter/material.dart';
import '../../domain/translation_dial_preflight.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/presentation/widgets/online_entry_guard.dart';
import '../../../../app/translation_providers.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../../../app/translation_access_providers.dart';
import '../../../../app/dial_recent_providers.dart';
import '../controller/translation_dial_input_owner.dart';
import '../../../../app/translation_finished_providers.dart';
import '../../../../app/translation_dial_binding_provider.dart';
import '../../../dialer/domain/dial_recent_call.dart';
import '../../../dialer/presentation/widgets/dial_recent_host.dart';
import '../../../dialer/domain/dial_phone_policy.dart';
import '../../../dialer/domain/system_dialer.dart';
import '../../../dialer/presentation/controller/dialer_controller.dart';
import '../../../dialer/presentation/pages/dialer_page.dart';
import '../../../dialer/presentation/widgets/dial_contact_suggestions_host.dart';
import 'translation_country_route.dart';
import '../controller/translation_setup_controller.dart';
import '../widgets/translation_presets.dart';
import '../widgets/native_translation_dial_summary.dart';
import '../widgets/translation_storage_status.dart';
import '../widgets/translation_record_save_status.dart';
import '../widgets/translation_model_sheet.dart';
import '../../domain/translation_access.dart';
import '../../../dialer/presentation/widgets/dial_permission_host.dart';
import '../../../dialer/domain/dial_permission.dart';
import '../../domain/translation_dial_request.dart';
import '../controller/translation_dial_session_binding.dart';
import 'translation_session_route.dart';
import '../../../../app/domestic_translation_dial.dart';
import '../../domain/sip/sip_lease.dart';
import '../../domain/sip/translation_call_plan.dart';
import '../widgets/domestic_translation_dial_summary.dart';
import '../widgets/translation_dial_pricing.dart';
import '../../domain/translation_directory.dart';

part 'translation_dialer_actions.dart';
part 'translation_dialer_inputs.dart';

class TranslationDialerRoute extends ConsumerStatefulWidget {
  const TranslationDialerRoute({
    super.key,
    this.number,
    this.name = '',
    this.countryIso,
    this.preview = false,
    this.systemDialer,
    this.sessionBinding,
    this.translationEntry = false,
  });
  final String? number;
  final String name;
  final String? countryIso;
  final bool preview, translationEntry;
  final SystemDialer? systemDialer;
  final TranslationDialSessionBinding? sessionBinding;
  @override
  ConsumerState<TranslationDialerRoute> createState() =>
      _TranslationDialerRouteState();
}

class _TranslationDialerRouteState
    extends ConsumerState<TranslationDialerRoute> {
  late final DialerController _dialer;
  late final TranslationDialInputOwner _input;
  late final TranslationSetupController _setup;
  late final void Function() _removeDial, _removeSetup;
  ProviderSubscription<TranslationAccess>? _locationSubscription;
  ProviderSubscription<AsyncValue<TranslationDirectory>>?
  _directorySubscription;
  DialerState _dial = const DialerState();
  bool _opening = false;
  bool _prepared = false;
  bool _entryNeedsDirectory = false, _entryEdited = false;
  @override
  void initState() {
    super.initState();
    _setup = ref.read(translationSetupProvider.notifier);
    _input = TranslationDialInputOwner(
      ref,
      preview: widget.preview,
      port: widget.systemDialer,
      translationEntry: widget.translationEntry,
    );
    _dialer = _input.controller;
    _removeDial = _dialer.addListener(_observeDial);
    _removeSetup = _setup.addListener((status) {
      if (status.ready) _restoreDialer();
      if (mounted) setState(() {});
    }, fireImmediately: false);
    if (!widget.preview) {
      _locationSubscription = ref.listenManual(
        translationAccessProvider,
        (_, access) => _syncLocationContext(access),
        fireImmediately: true,
      );
      _directorySubscription = ref.listenManual(translationDirectoryProvider, (
        _,
        value,
      ) {
        if (value.isLoading) {
          return;
        }
        Future.microtask(() {
          if (!mounted || !_input.current(ref) || !_setup.status.ready) return;
          if (!value.hasError && value.valueOrNull != null) {
            if (_entryNeedsDirectory && !_entryEdited) _prepared = false;
            _entryNeedsDirectory = false;
            final access = ref.read(translationAccessProvider);
            _setup.directory(
              value.requireValue,
              callerCountryIso: access.countryIso ?? '',
              overseas: access.countryIso != 'CN' || access.forced,
            );
          }
          _restoreDialer();
        });
      }, fireImmediately: true);
    }
    Future.microtask(() {
      if (_current && _setup.status.ready) _restoreDialer();
    });
  }

  @override
  void dispose() {
    _removeDial();
    _removeSetup();
    _locationSubscription?.close();
    _directorySubscription?.close();
    _input.release();
    super.dispose();
  }

  void _update(VoidCallback change) => setState(change);

  bool get _current =>
      mounted &&
      _input.current(ref) &&
      ModalRoute.of(context)?.isCurrent == true &&
      identical(ref.read(translationSetupProvider.notifier), _setup);
  bool get _editable =>
      _current &&
      !_opening &&
      !_dial.busy &&
      _setup.status.ready &&
      (_prepared || widget.number == null);

  void _enable(bool value) {
    _setup.enable(value);
    _setCountry(_setup.snapshot.country);
  }

  Future<void> _country() async {
    if (!_editable) return;
    final iso = await pushTranslationCountry(
      context,
      selected: _dial.countryIso,
      countries: _setup.countries,
      preview: widget.preview,
    );
    if (!_editable || iso == null) return;
    _entryEdited = true;
    _setup.country(
      iso,
      supportedPeerCodes: _supportedLanguageCodes(caller: false),
    );
    _setCountry(iso);
  }

  Object get _confirmationSnapshot => (
    widget.preview ? null : ref.read(loginEpochProvider),
    _dial.input,
    _dial.countryIso,
    _setup.snapshot,
    widget.preview ? null : ref.read(translationAccessProvider).countryIso,
    widget.preview ? null : ref.read(translationAccessProvider).forced,
    widget.preview ? null : ref.read(selectedTranslationModelProvider)?.id,
    widget.preview ? null : ref.read(translationDirectoryProvider).valueOrNull,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.preview || kIsWeb) return _page(context, _enable, () => true);
    return DialPermissionHost(
      enabled: _setup.snapshot.enabled,
      ready: _setup.status.ready,
      onEnabled: _enable,
      builder: (context, permission) => _page(
        context,
        permission.toggle,
        () => permission.snapshot.stage == DialPermissionStage.ready,
      ),
    );
  }

  Widget _page(
    BuildContext context,
    ValueChanged<bool> requestEnable,
    bool Function() canProceed,
  ) {
    final options = ref.watch(translationDirectoryProvider);
    final configured = widget.preview
        ? null
        : ref.watch(selectedTranslationModelProvider);
    final state = _setup.snapshot;
    final access = widget.preview
        ? const TranslationAccess(countryIso: 'US', forced: false)
        : ref.watch(translationAccessProvider);
    final busy =
        _opening ||
        _dial.busy ||
        !_setup.status.ready ||
        (state.enabled && access.loading);
    String languageName(String code) =>
        _setup.languages
            .where((language) => language.code == code)
            .firstOrNull
            ?.label ??
        '请选择';
    final languages =
        '我方 ${languageName(state.caller)}  ⇄  ${languageName(state.peer)} 对方';
    return DialerPage(
      state: widget.preview && !state.enabled ? _dial : _dial.copy(message: ''),
      suggestions: Column(
        children: [
          DialRecentHost(
            query: _dial.input,
            enabled: !busy,
            onSelect: _restoreRecent,
          ),
          DialContactSuggestionsHost(
            query: _dial.input,
            enabled: !busy,
            onSelect: (item) {
              _restoreContact(item.phone, item.name);
            },
          ),
        ],
      ),
      onCountry: _country,
      onDelete: () {
        if (_editable) {
          _entryEdited = true;
          _dialer.delete();
        }
      },
      onClear: () {
        if (_editable) {
          _entryEdited = true;
          _dialer.clear();
        }
      },
      onDigit: (value) {
        if (!_editable) return;
        _entryEdited = true;
        _dialer.digit(value);
      },
      onDial: () => _call(requestEnable, canProceed),
      onClose: () {
        if (_current) Navigator.pop(context);
      },
      dialLabel: state.enabled ? '实时翻译呼叫' : '普通呼叫',
      translationEnabled: state.enabled,
      bottomNote: state.enabled
          ? TranslationDialPricing(model: configured)
          : null,
      configuration: Column(
        children: [
          if (widget.preview)
            const Text(
              'MOCK · 配置仅保存在本次演练，不修改正式设置',
              style: TextStyle(fontSize: 12, color: Color(0xFF986300)),
            )
          else if (_setup.status.loading ||
              _setup.status.saving ||
              _setup.status.error.isNotEmpty)
            TranslationStorageStatus(controller: _setup),
          if (!widget.preview)
            TranslationRecordSaveStatus(
              state: ref.watch(translationFinishedRecorderProvider),
              onRetry: ref
                  .read(translationFinishedRecorderProvider.notifier)
                  .retry,
            ),
          if (!widget.preview && access.countryIso == 'CN' && !access.forced)
            DomesticTranslationDialSummary(
              enabled: state.enabled,
              busy: busy,
              languages: languages,
              onLanguages: busy
                  ? null
                  : () => _presetsCall(requestEnable, canProceed),
            )
          else
            NativeTranslationDialSummary(
              model: access.loading
                  ? ''
                  : access.canSelect
                  ? (widget.preview
                        ? overseasModelLabels[state.provider] ?? state.provider
                        : options.isLoading
                        ? '模型加载中'
                        : options.hasError
                        ? '模型加载失败，点击重试'
                        : configured?.name ?? '当前位置无可用模型')
                  : access.countryIso == null
                  ? '位置待确认'
                  : '当前地区暂不支持',
              languages: languages,
              translationEnabled: state.enabled,
              multiplier: configured?.multiplier,
              onModel: busy
                  ? null
                  : () {
                      if (!_editable) return;
                      if (access.countryIso == null) {
                        // The old Android dialer made the unresolved-region
                        // state actionable. Reuse the country route's
                        // location card so Android can request permission (or
                        // open Settings when it is permanently denied).
                        _country();
                        return;
                      }
                      showTranslationModelSheet(
                        context,
                        _setup,
                        preview: widget.preview,
                      );
                    },
              onLanguages: busy
                  ? null
                  : () => _presetsCall(requestEnable, canProceed),
            ),
        ],
      ),
    );
  }
}
