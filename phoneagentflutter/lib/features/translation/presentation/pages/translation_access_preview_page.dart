import '../../../../app/translation_directory_providers.dart';
import '../../../../app/domestic_translation_settings_providers.dart';
import '../../data/sip/preview_domestic_translation_settings.dart';
import '../controller/domestic_translation_settings_controller.dart';
import 'package:flutter/material.dart';
import '../../../../app/dial_permission_providers.dart';
import '../../../dialer/data/preview_dial_permission_port.dart';
import '../../../dialer/domain/dial_permission.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/settings_providers.dart';
import '../../../../app/developer_network_providers.dart';
import '../../../../app/online_entry_providers.dart';
import '../../../settings/domain/network_availability.dart';
import '../../../settings/domain/developer_network_mode.dart';
import '../../../../app/outbound_number_providers.dart';
import '../../../settings/data/preview_outbound_number_repository.dart';
import '../../../../app/translation_access_providers.dart';
import '../../../../app/translation_catalog_providers.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../../app/translation_quality_providers.dart';
import '../../../../app/dial_recent_providers.dart';
import '../../../../app/dial_contact_providers.dart';
import '../../../contacts/data/lpinyin_contact_dictionary.dart';
import '../../../dialer/data/preview_dial_contacts.dart';
import '../../../dialer/data/preview_dial_recent_source.dart';
import '../../../dialer/data/system_dialer_channel.dart';
import '../../../dialer/domain/dial_contact_suggestion.dart';
import '../../../dialer/domain/dial_recent_call.dart';
import '../../../dialer/presentation/controller/dial_contacts_controller.dart';
import '../../../dialer/presentation/controller/dial_recent_controller.dart';
import '../../../settings/presentation/pages/developer_tools_route.dart';
import '../../data/preview_translation_location.dart';
import '../../data/preview_translation_configuration.dart';
import '../../domain/translation_location.dart';
import '../../domain/translation_model_quality.dart';
import '../widgets/translation_access_message.dart';
import 'translation_dialer_route.dart';
import '../controller/translation_completion_preview_controller.dart';
import '../controller/translation_dial_session_binding.dart';
import '../widgets/translation_session_preview_controls.dart';
import '../widgets/translation_archive_status.dart';

/// Same production routes/policies. All network, location, storage and dialing
/// boundaries are replaced; nested navigator keeps every page in this scope.
class TranslationAccessPreviewPage extends StatefulWidget {
  const TranslationAccessPreviewPage({super.key});
  @override
  State<TranslationAccessPreviewPage> createState() =>
      _TranslationAccessPreviewPageState();
}

class _TranslationAccessPreviewPageState
    extends State<TranslationAccessPreviewPage> {
  final _location = PreviewTranslationLocation()
    ..cached = TrustedTranslationLocation('CN', 1);
  final _store = PreviewTranslationPreferenceStore();
  final _billing = PreviewTranslationBilling();
  final _outbound = PreviewOutboundNumberRepository();
  final _domesticModels = PreviewDomesticProviderRepository();
  // Region-gate scenarios start after the location explanation was handled.
  // Permission sequencing itself has a separate isolated preview.
  final _permissions = PreviewDialPermissionPort(supportsCallLog: false);
  final _permissionMemory = DialPermissionMemory()..locationShown = true;
  bool _testControls = true;
  bool _callFlow = false;
  final _completion = TranslationCompletionPreviewController();
  @override
  void dispose() {
    _completion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      translationDirectoryProvider.overrideWith(
        (ref) async => previewTranslationDirectory,
      ),
      domesticTranslationSettingsProvider.overrideWith((_) {
        final controller = DomesticTranslationSettingsController(
          repository: _domesticModels,
          isCurrent: () => mounted,
        );
        controller.load();
        return controller;
      }),
      dialPermissionPortProvider.overrideWithValue(_permissions),
      dialPermissionMemoryProvider.overrideWithValue(_permissionMemory),
      accountApiProvider.overrideWith(
        (_) => throw StateError('Preview cannot access account API'),
      ),
      developerModeProvider.overrideWith((_) => true),
      networkAvailabilitySourceProvider.overrideWithValue(
        const UnknownNetworkAvailability(),
      ),
      developerNetworkModeProvider.overrideWith(
        (_) => DeveloperNetworkMode.normal,
      ),
      outboundNumberRepositoryProvider.overrideWithValue(_outbound),
      translationTestControlsProvider.overrideWithValue(_testControls),
      translationPreferenceStoreProvider.overrideWithValue(_store),
      translationLocationSourceProvider.overrideWithValue(_location),
      translationLocationStoreProvider.overrideWithValue(_location),
      translationBillingRepositoryProvider.overrideWithValue(_billing),
      translationCatalogRepositoryProvider.overrideWithValue(
        const PreviewTranslationCatalog(),
      ),
      translationModelQualityProvider.overrideWith(
        (_, region) async => {
          'OPENAI': TranslationModelSample.reachable(140),
          'GEMINI': TranslationModelSample.reachable(620),
        },
      ),
      dialContactsProvider.overrideWith((_) {
        final controller = DialContactsController(
          PreviewDialContacts(),
          const DialSuggestionPolicy(LpinyinContactDictionary()),
        );
        controller.load();
        return controller;
      }),
      dialRecentProvider.overrideWith((_) {
        final controller = DialRecentController(
          const PreviewDialRecentSource(DialRecentSource.system),
          const PreviewDialRecentSource(DialRecentSource.app),
        );
        controller.load();
        return controller;
      }),
    ],
    child: Scaffold(
      appBar: AppBar(title: const Text('MOCK · 翻译准入演练')),
      body: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => Consumer(
            builder: (context, ref, _) {
              final access = ref.watch(translationAccessProvider);
              final billing = ref.watch(translationBillingProvider);
              final settings = ref.watch(translationSetupProvider);
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('合成位置/倍率/节点/联系人，内存偏好；不发短信、电话或真实HTTP'),
                  Text(
                    billing.hasError
                        ? '合成倍率读取失败'
                        : billing.isLoading
                        ? '合成倍率读取中'
                        : '合成倍率已读取',
                  ),
                  Text(translationAccessMessage(access)),
                  Text(
                    '偏好：${settings.value.provider} / ${settings.value.region} / 强制 ${settings.value.forceBackend}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final iso in ['未知', 'CN', 'US'])
                        OutlinedButton(
                          onPressed: () {
                            _location.cached = iso == '未知'
                                ? null
                                : TrustedTranslationLocation(iso, 1);
                            _location.result = TranslationLocationResult(
                              TranslationLocationStatus.resolved,
                              countryIso: iso == '未知' ? 'US' : iso,
                            );
                            ref.invalidate(translationLocationProvider);
                          },
                          child: Text('模拟 $iso'),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('构建允许翻译调试'),
                    value: _testControls,
                    onChanged: (value) => setState(() => _testControls = value),
                  ),
                  SwitchListTile(
                    title: const Text('配置到通话流程（MOCK）'),
                    subtitle: const Text('同一拨号按钮进入共享通话页；仅内存服务与记录'),
                    value: _callFlow,
                    onChanged: (value) => setState(() => _callFlow = value),
                  ),
                  SwitchListTile(
                    title: const Text('原音播放（MOCK）'),
                    value: _completion.originalAudio.enabled,
                    onChanged: (value) => setState(() {
                      _completion.originalAudio = _completion.originalAudio
                          .copy(enabled: value);
                    }),
                  ),
                  ListenableBuilder(
                    listenable: _completion,
                    builder: (_, __) => Column(
                      children: [
                        Text(
                          'MOCK · 流程记录 ${_completion.recentState.records.length} 条\n'
                          '${_completion.lastDial == null ? '' : '${_completion.lastDial!.preferences.provider} / ${_completion.lastDial!.serviceRegion} / ${_completion.lastDial!.preferences.caller}→${_completion.lastDial!.preferences.peer}'}',
                        ),
                        Text(
                          'MOCK · 服务端归档 ${_completion.archivePorts.archived.length} 条 / 请求 ${_completion.archivePorts.attempts} 次',
                        ),
                        TranslationArchiveStatusView(
                          state: _completion.archive.snapshot,
                          onRetry: _completion.archive.retry,
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('归档接口失败（MOCK）'),
                    value: _completion.archivePorts.failArchive,
                    onChanged: (value) => setState(
                      () => _completion.archivePorts.failArchive = value,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('倍率查询失败'),
                    value: _billing.fail,
                    onChanged: (value) {
                      setState(() => _billing.fail = value);
                      ref.invalidate(translationBillingProvider);
                    },
                  ),
                  FilledButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TranslationDialerRoute(
                          number: '+12025550123',
                          systemDialer: PreviewSystemDialer(),
                          sessionBinding: !_callFlow
                              ? null
                              : TranslationDialSessionBinding(
                                  create: _completion.createDial,
                                  header: (_, controller) =>
                                      TranslationSessionPreviewControls(
                                        fixture: _completion.activeFixture!,
                                        state: controller.snapshot,
                                      ),
                                ),
                        ),
                      ),
                    ),
                    child: const Text('进入共享翻译拨号页'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeveloperToolsRoute(),
                      ),
                    ),
                    child: const Text('进入共享开发者设置'),
                  ),
                  const Text('未知位置：即使强制也不能发起通话；模拟获取位置会返回合成美国，不使用系统定位。'),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
