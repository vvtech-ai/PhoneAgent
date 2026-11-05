import '../../../call_models/presentation/widgets/call_model_selection_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/call_model_refresh_providers.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../app/clone_readiness_provider.dart';
import '../../../../app/home_notification_providers.dart';
import '../../../../app/call_model_quality_providers.dart';
import '../../../../app/conversation_providers.dart';
import '../../../../app/task_error_status_providers.dart';
import '../../../../app/points_providers.dart';
import '../../../../app/invite_providers.dart';
import '../controller/shell_welfare_navigation.dart';
import '../../../trusted_caller/presentation/widgets/trusted_caller_home_guide_host.dart';
import '../../../../app/translation_archive_providers.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../settings/presentation/pages/settings_route.dart';
import '../../../call_models/domain/call_models.dart';
import '../../../call_models/presentation/pages/call_models_page.dart';
import '../../../call_models/presentation/pages/call_voices_page.dart';
import '../../../call_models/presentation/widgets/system_voice_preview_host.dart';
import '../../../call_models/presentation/widgets/voice_sheet_frame.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../home/domain/home_config.dart';
import '../../../contacts/presentation/pages/contacts_route.dart';
import '../../../contacts/presentation/widgets/contact_tab_entry_gate.dart';
import '../../../commerce/presentation/pages/membership_route.dart';
import '../../../identity/presentation/pages/identity_route.dart';
import '../../../tasks/domain/task_records.dart';
import '../../../tasks/presentation/pages/tasks_presentation_host.dart';
import '../../../../app/task_pinned_preference_providers.dart';
import '../widgets/floating_navigation.dart';
import '../widgets/shell_model_sheet.dart';
import '../../../dialer/presentation/pages/dialer_route.dart';
import '../controller/shell_task_navigation.dart';
import '../controller/shell_clone_navigation.dart';
import '../../../../app/home_card_preference_providers.dart';
import '../../../home/domain/home_card_preferences.dart';

class ShellRoute extends ConsumerStatefulWidget {
  const ShellRoute({super.key});
  @override
  ConsumerState<ShellRoute> createState() => _ShellRouteState();
}

class _ShellRouteState extends ConsumerState<ShellRoute>
    with WidgetsBindingObserver {
  int _tab = 0;
  String? _panel;
  bool _modelSheet = false;
  int _entryGeneration = 0;
  bool _notificationReadScheduled = false;
  late final _taskNavigation = ShellTaskNavigation(
    ref: ref,
    context: () => context,
    current: () => mounted && ModalRoute.of(context)?.isCurrent == true,
    generation: () => _entryGeneration,
    onReturned: () {
      _refreshModels();
      _scheduleNotificationRead();
    },
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    ref.invalidate(inviteAvailabilityProvider);
    if (_modelSheet || _panel == 'models') {
      ref.read(catalogControllerProvider.notifier).load();
    }
    if (_tab == 0) {
      _refreshHome();
    } else {
      _refreshModels();
    }
  }

  bool get _tasksVisible =>
      mounted &&
      _tab == 2 &&
      _panel == null &&
      !_modelSheet &&
      ModalRoute.of(context)?.isCurrent == true;

  void _scheduleNotificationRead() {
    if (!_tasksVisible || _notificationReadScheduled) return;
    _notificationReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationReadScheduled = false;
      if (!_tasksVisible) return;
      final state = ref.read(homeNotificationControllerProvider);
      if (state.ready &&
          !state.loading &&
          !state.saving &&
          state.notice.isEmpty &&
          state.pending.isNotEmpty) {
        ref
            .read(homeNotificationControllerProvider.notifier)
            .markAllPendingRead();
      }
    });
  }

  Future<void> _refreshHome({bool retryStorage = false}) async {
    if (!mounted) return;
    ref.invalidate(inviteAvailabilityProvider);
    final work = <Future<void>>[
      _refreshModels(),
      ref.read(homeControllerProvider.notifier).refresh(),
      if (ref.read(homeNotificationReadStoreProvider) != null)
        ref.read(taskControllerProvider.notifier).refresh(),
      if (retryStorage &&
          ref.read(homeNotificationControllerProvider).notice.isNotEmpty)
        ref.read(homeNotificationControllerProvider.notifier).retryStorage(),
    ];
    await Future.wait(work);
  }

  void _selectTab(int tab) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final previous = _tab;
    _entryGeneration++;
    setState(() => _tab = tab);
    if (tab == 0) _refreshHome();
    if (tab == 2 || tab == 3) _refreshModels();
    if (tab == 2) {
      if (previous != 2) ref.read(taskControllerProvider.notifier).refresh();
      _scheduleNotificationRead();
    }
  }

  Future<void> _refreshModels() {
    ref.invalidate(catalogControllerProvider);
    return ref.read(callModelRefreshProvider)();
  }

  void _back() {
    setState(() {
      _entryGeneration++;
      if (_modelSheet) {
        ref.read(callModelQualityProvider.notifier).cancel();
        _modelSheet = false;
      } else {
        _panel = null;
      }
    });
    _refreshModels();
  }

  Widget _behindModelSheet(Widget child) => IgnorePointer(
    ignoring: _modelSheet,
    child: ExcludeFocus(
      excluding: _modelSheet,
      child: ExcludeSemantics(excluding: _modelSheet, child: child),
    ),
  );

  void _refreshModelQuality() {
    final models = ref.read(callModelControllerProvider).catalog?.models ?? [];
    ref
        .read(callModelQualityProvider.notifier)
        .refresh(models.map((model) => model.id));
  }

  void _openModelSheet() {
    _refreshModels();
    ++_entryGeneration;
    setState(() => _modelSheet = true);
  }

  Future<bool> _selectModel(CallModel model) {
    final generation = _entryGeneration;
    final controller = ref.read(callModelControllerProvider.notifier);
    return selectCallModelWithFeedback(
      context,
      controller,
      model,
      readState: () => ref.read(callModelControllerProvider),
      isCurrent: () =>
          mounted &&
          generation == _entryGeneration &&
          identical(controller, ref.read(callModelControllerProvider.notifier)),
    );
  }

  Future<void> _voices(CallModel model) async {
    final generation = _entryGeneration;
    final controller = ref.read(callModelControllerProvider.notifier);
    if (!await _selectModel(model) ||
        !mounted ||
        generation != _entryGeneration) {
      return;
    }
    controller.loadVoices(model.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x73000000),
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => VoiceSheetFrame(
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(callModelControllerProvider);
            return SystemVoicePreviewHost(
              modelId: model.id,
              builder: (preview, onPreview, stopPreview) => CallVoicesPage(
                state: state,
                preview: preview,
                onPreview: onPreview,
                onBack: () => Navigator.pop(sheetContext),
                onRetry: () => controller.loadVoices(model.id),
                onSelect: controller.selectVoice,
                onSelectClone: () async {
                  if (await stopPreview() && sheetContext.mounted) {
                    await controller.selectClone();
                  }
                },
                onDeleteClone: (id) async {
                  if (await stopPreview() && sheetContext.mounted) {
                    await controller.deleteClone(id);
                    if (mounted) ref.invalidate(cloneCatalogProvider);
                  }
                },
                onCreateClone: () {
                  Navigator.pop(sheetContext);
                  _createClone(null, model.capabilityProvider);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _entry(HomeCard card) => _taskNavigation.entry(card);

  Future<void> _identity() async {
    await Navigator.of(context).push<IdentityDestination>(
      MaterialPageRoute(
        builder: (_) => IdentityRoute(onCreateClone: _createClone),
      ),
    );
    if (mounted) _refreshModels();
  }

  Future<void> _createClone([BuildContext? source, String? targetModelId]) =>
      openShellCloneFlow(
        source ?? context,
        ref,
        targetModelId: targetModelId,
        isCurrent: () => mounted,
      );

  Future<void> _wallet() async {
    ref.read(pointsWalletControllerProvider.notifier).refresh();
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const MembershipRoute()));
    if (mounted) {
      ref.read(pointsWalletControllerProvider.notifier).refresh();
      _refreshModels();
    }
  }

  Future<void> _welfare() => openShellWelfare(
    context,
    onReturned: () {
      ref.invalidate(inviteAvailabilityProvider);
      _refreshModels();
    },
  );

  Future<void> _task(TaskRecord row) => _taskNavigation.task(row);

  @override
  Widget build(BuildContext context) {
    ref.watch(homeNotificationControllerProvider);
    ref.listen(homeNotificationControllerProvider, (_, next) {
      if (next.ready &&
          !next.loading &&
          !next.saving &&
          next.notice.isEmpty &&
          next.pending.isNotEmpty) {
        _scheduleNotificationRead();
      }
    });
    ref.watch(taskErrorNetworkRecoveryProvider);
    ref.watch(translationArchiveProvider.notifier);
    final home = ref.watch(homeControllerProvider),
        models = ref.watch(callModelControllerProvider);
    final homePreferences = ref.watch(homeCardPreferenceProvider);
    final installedVersion =
        ref.watch(homeInstalledVersionProvider).valueOrNull ?? '';
    final quality = _modelSheet ? ref.watch(callModelQualityProvider) : null;
    ref.listen(callModelControllerProvider, (previous, next) {
      if (_modelSheet && next.catalog != null && previous?.catalog == null) {
        final generation = _entryGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _modelSheet && generation == _entryGeneration) {
            _refreshModelQuality();
          }
        });
      }
    });
    final controller = ref.read(callModelControllerProvider.notifier);
    final wallet = ref.watch(pointsWalletControllerProvider);
    final inviteEntry = ref.watch(inviteEntryPresentationProvider);
    final cloneReadiness = _panel == 'models'
        ? ref.watch(cloneReadinessProvider)
        : null;
    final membership = _panel == 'models' || _modelSheet
        ? ref.watch(catalogControllerProvider)
        : null;
    final page = _panel == 'models'
        ? CallModelsPage(
            state: models,
            membership: membership?.loading == true
                ? null
                : membership?.membership,
            commerceCatalog: membership?.catalog,
            onBack: _back,
            onRetry: controller.load,
            onSelect: _selectModel,
            onVoices: _voices,
            onCreateClone: _createClone,
            clonePricePoints: ref.watch(
              cloneEntryPriceProvider(models.catalog?.current?.id),
            ),
            hasReadyClone: cloneReadiness?.isLoading == true
                ? null
                : cloneReadiness?.valueOrNull,
            cloneReadFailed: cloneReadiness?.hasError ?? false,
          )
        : _tab == 0
        ? HomePage(
            visibleCards: HomeCardPreferencePolicy.project(
              home.config.cards,
              homePreferences.preferences,
            ),
            installedVersion: installedVersion,
            state: home,
            modelName: models.catalog?.current?.name ?? '选择模型',
            modelMultiplier: models.catalog?.current?.multiplier,
            onModels: _openModelSheet,
            onRefresh: () => _refreshHome(retryStorage: true),
            onEntry: _entry,
            pointsBalance: wallet.account?.availableBalance,
            onPoints: _wallet,
            onWelfare: inviteEntry?.visible == true ? _welfare : null,
          )
        : _tab == 3
        ? SettingsRoute(
            onIdentity: _identity,
            onModels: () {
              _refreshModels();
              setState(() => _panel = 'models');
            },
          )
        : _tab == 2
        ? TasksPresentationHost(
            key: ValueKey(ref.watch(loginEpochProvider)),
            preferences: ref.watch(taskPinnedPreferenceProvider),
            state: ref.watch(taskControllerProvider),
            onRefresh: ref.read(taskControllerProvider.notifier).refresh,
            onOpen: _task,
            onLoadMore: ref.read(taskControllerProvider.notifier).loadMore,
            onPin: ref.read(taskControllerProvider.notifier).pin,
            onDelete: ref.read(taskControllerProvider.notifier).hide,
            onClearUnread: ref
                .read(taskControllerProvider.notifier)
                .clearUnread,
          )
        : const ContactsRoute(loadOnMount: false);
    return TrustedCallerHomeGuideHost(
      active: _tab == 0 && _panel == null && !_modelSheet,
      child: PopScope(
        canPop: _panel == null && !_modelSheet,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: NativePageBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    bottom: _panel == null
                        ? FloatingNavigation.contentInset(context)
                        : 0,
                    child: _behindModelSheet(page),
                  ),
                  if (_panel == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _behindModelSheet(
                        ContactTabEntryGate(
                          selected: _tab,
                          entryGeneration: _entryGeneration,
                          enabled: _panel == null && !_modelSheet,
                          onSelected: _selectTab,
                          builder: (select) => FloatingNavigation(
                            selected: _tab,
                            onSelected: select,
                            onDial: () => openDialer(context),
                          ),
                        ),
                      ),
                    ),
                  if (_modelSheet) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _back,
                        child: Container(color: const Color(0x73000000)),
                      ),
                    ),
                    ShellModelSheet(
                      child: CallModelsPage(
                        state: models,
                        membership: membership?.loading == true
                            ? null
                            : membership?.membership,
                        commerceCatalog: membership?.catalog,
                        sheet: true,
                        readings: quality?.readings ?? const {},
                        qualityBusy: quality?.busy ?? false,
                        onRefreshQuality: () async {
                          await _refreshModels();
                          if (mounted && _modelSheet) _refreshModelQuality();
                        },
                        onBack: _back,
                        onRetry: controller.load,
                        onVoices: _voices,
                        onSelect: (model) async {
                          final generation = _entryGeneration;
                          if (await selectCallModelWithFeedback(
                                context,
                                controller,
                                model,
                                readState: () =>
                                    ref.read(callModelControllerProvider),
                                isCurrent: () =>
                                    mounted &&
                                    generation == _entryGeneration &&
                                    identical(
                                      controller,
                                      ref.read(
                                        callModelControllerProvider.notifier,
                                      ),
                                    ),
                              ) &&
                              mounted &&
                              generation == _entryGeneration &&
                              _modelSheet) {
                            _back();
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
