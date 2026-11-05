import '../widgets/call_model_selection_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/call_model_refresh_providers.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../app/call_model_quality_providers.dart';
import '../../domain/call_models.dart';
import '../controller/call_model_quality_controller.dart';
import 'call_models_page.dart';

/// Owns only this modal's latency requests, independent of the home sheet.
class CallModelSheet extends ConsumerStatefulWidget {
  const CallModelSheet({super.key, this.selectedModelId});
  final String? selectedModelId;

  static Future<CallModel?> open(
    BuildContext context, {
    String? selectedModelId,
  }) => showModalBottomSheet<CallModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0x73000000),
    constraints: const BoxConstraints(maxWidth: 420),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => CallModelSheet(selectedModelId: selectedModelId),
  );

  @override
  ConsumerState<CallModelSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<CallModelSheet>
    with WidgetsBindingObserver {
  late final _epoch = ref.read(loginEpochProvider);
  late final _quality = CallModelQualityController(
    ref.read(callModelQualityRepositoryProvider),
  );
  late final void Function() _removeListener;
  CallModelQualityState _qualityState = const CallModelQualityState();
  List<String> _ids = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ProviderScope.containerOf(
      context,
      listen: false,
    ).invalidate(catalogControllerProvider);
    _removeListener = _quality.addListener((next) {
      if (mounted) setState(() => _qualityState = next);
    }, fireImmediately: false);
    Future.microtask(() {
      if (mounted && ref.read(loginEpochProvider) == _epoch) {
        ref.read(callModelRefreshProvider)();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _removeListener();
    _quality.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(catalogControllerProvider.notifier).load();
      ref.read(callModelRefreshProvider)();
    }
  }

  void _syncModels(List<CallModel> models) {
    final ids = models.map((model) => normalizeProvider(model.id)).toList();
    if (listEquals(ids, _ids)) return;
    _ids = ids;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _quality.cancel();
      _quality.refresh(_ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(loginEpochProvider) != _epoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    final models = ref.watch(callModelControllerProvider);
    final membership = ref.watch(catalogControllerProvider);
    final controller = ref.read(callModelControllerProvider.notifier);
    _syncModels(models.catalog?.models ?? const []);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height * .85).clamp(0, 500),
        ),
        child: CallModelsPage(
          state: models,
          membership: membership.loading ? null : membership.membership,
          commerceCatalog: membership.catalog,
          sheet: true,
          selectedModelId: widget.selectedModelId,
          readings: _qualityState.readings,
          qualityBusy: _qualityState.busy,
          onRefreshQuality: () {
            ref.read(callModelRefreshProvider)();
            ref.read(catalogControllerProvider.notifier).load();
            _quality.refresh(_ids);
          },
          onBack: () => Navigator.pop(context),
          onRetry: controller.load,
          onVoices: (_) {},
          onSelect: (model) async {
            if (await selectCallModelWithFeedback(
                  context,
                  controller,
                  model,
                  readState: () => ref.read(callModelControllerProvider),
                  isCurrent: () =>
                      mounted &&
                      ref.read(loginEpochProvider) == _epoch &&
                      identical(
                        controller,
                        ref.read(callModelControllerProvider.notifier),
                      ),
                ) &&
                mounted &&
                context.mounted &&
                ref.read(loginEpochProvider) == _epoch) {
              Navigator.pop(context, model);
            }
          },
        ),
      ),
    );
  }
}
