import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_access_providers.dart';
import '../../../../app/translation_directory_providers.dart';
import '../../../../app/translation_model_selection_providers.dart';
import '../../../../app/translation_quality_providers.dart';
import '../../../../app/domestic_translation_quality_providers.dart';
import '../../../../app/business_providers.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../domain/translation_model_selection.dart';
import '../../domain/translation_model_quality.dart';
import '../controller/translation_setup_controller.dart';
import 'native_translation_model_panel.dart';
import 'native_translation_model_option.dart';
import 'translation_model_selection_feedback.dart';

const overseasModelLabels = {
  'OPENAI': 'GPT Live Translate',
  'GEMINI': 'Gemini Live',
  'QWEN': '千问国际站',
};

Future<void> showTranslationModelSheet(
  BuildContext context,
  TranslationSetupController controller, {
  bool preview = false,
}) => showModalTranslationSelection(context, controller, preview: preview);

Future<void> showModalTranslationSelection(
  BuildContext context,
  TranslationSetupController controller, {
  bool preview = false,
  WidgetBuilder? builder,
}) async {
  if (!context.mounted ||
      ModalRoute.of(context)?.isCurrent != true ||
      !controller.mounted ||
      !controller.status.ready) {
    return;
  }
  final container = ProviderScope.containerOf(context);
  final access = container.read(translationAccessProvider);
  final epoch = container.read(loginEpochProvider);
  final before = preview
      ? controller.snapshot.provider
      : container.read(selectedTranslationModelProvider)?.id;
  if (!preview) container.invalidate(translationDirectoryProvider);
  final value = await showNativeTranslationModelPanel<String>(
    context,
    builder:
        builder ??
        (_) => RouteProviderScope(
          container: container,
          child: TranslationModelSheet(
            selected: preview
                ? controller.snapshot.provider
                : controller.snapshot.overseasModelId,
            region: controller.snapshot.region,
            preview: preview,
          ),
        ),
  );
  if (!context.mounted ||
      ModalRoute.of(context)?.isCurrent != true ||
      !controller.mounted ||
      !controller.status.ready ||
      value == null) {
    return;
  }
  final current = container.read(translationAccessProvider);
  if (!preview &&
      (current.countryIso != access.countryIso ||
          current.forced != access.forced ||
          current.loading ||
          epoch != container.read(loginEpochProvider))) {
    return;
  }
  if (preview) {
    controller.provider(value);
    if (before != value) {
      showTranslationModelSelectionFeedback(
        context,
        overseasModelLabels[value] ?? value,
      );
    }
    return;
  }
  final options = container.read(translationDirectoryProvider);
  if (options.isLoading || options.hasError) return;
  final directory = options.valueOrNull;
  final model = directory?.model(value);
  final overseas = current.countryIso != 'CN' || current.forced;
  if (model == null ||
      !translationModelSupported(model, overseas: overseas) ||
      directory?.country(current.countryIso ?? '')?.modelIds.contains(value) !=
          true) {
    return;
  }
  controller.selectModel(value, model.engine, overseas: overseas);
  if (before != value) {
    showTranslationModelSelectionFeedback(context, model.name);
  }
}

class TranslationModelSheet extends ConsumerStatefulWidget {
  const TranslationModelSheet({
    super.key,
    required this.selected,
    required this.region,
    this.preview = false,
    this.domestic = false,
  });
  final String selected, region;
  final bool preview, domestic;
  @override
  ConsumerState<TranslationModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends ConsumerState<TranslationModelSheet> {
  bool _previewFailure = false;
  Object? _epoch;
  String? _country;
  bool _forced = false;
  @override
  void initState() {
    super.initState();
    _epoch = ref.read(loginEpochProvider);
    final access = ref.read(translationAccessProvider);
    _country = access.countryIso;
    _forced = access.forced;
  }

  bool get _admittedNow {
    if (widget.preview) return true;
    final access = ref.read(translationAccessProvider);
    final options = ref.read(translationDirectoryProvider);
    return _epoch == ref.read(loginEpochProvider) &&
        !options.isLoading &&
        !options.hasError &&
        !access.loading &&
        _country == access.countryIso &&
        _forced == access.forced;
  }

  bool get _current => mounted && ModalRoute.of(context)?.isCurrent == true;
  @override
  Widget build(BuildContext context) {
    final options = widget.preview
        ? null
        : ref.watch(translationDirectoryProvider);
    final directory =
        options != null &&
            (!options.isLoading || options.isRefreshing) &&
            !options.hasError
        ? options.valueOrNull
        : null;
    final access = ref.watch(translationAccessProvider);
    final admitted =
        widget.preview ||
        (_epoch == ref.watch(loginEpochProvider) &&
            !access.loading &&
            access.countryIso != null &&
            (widget.domestic
                ? access.countryIso == 'CN' && !access.forced
                : access.canSelect));
    final selected = widget.preview
        ? widget.selected
        : ref.watch(selectedTranslationModelProvider)?.id;
    final models =
        directory?.country(access.countryIso ?? '')?.modelIds ??
        const <String>[];
    bool uses(String transport) =>
        models.any((id) => directory?.model(id)?.transport == transport);
    final backendQuality = widget.preview
        ? AsyncData<Map<String, TranslationModelSample>>({
            'OPENAI': _previewFailure
                ? const TranslationModelSample.unavailable()
                : TranslationModelSample.reachable(140),
            'GEMINI': TranslationModelSample.reachable(620),
          })
        : admitted && uses('BACKEND_WEBRTC')
        ? ref.watch(translationModelQualityProvider(widget.region))
        : const AsyncData<Map<String, TranslationModelSample>>({});
    final localQuality = !widget.preview && admitted && uses('LOCAL_SIP')
        ? ref.watch(domesticTranslationModelQualityProvider)
        : const AsyncData<Map<String, TranslationModelSample>>({});
    final qualityBusy = backendQuality.isLoading || localQuality.isLoading;
    TranslationModelSample? sample(String id) {
      final model = directory?.model(id);
      final local = model?.transport == 'LOCAL_SIP';
      final values = local
          ? localQuality.valueOrNull
          : backendQuality.valueOrNull;
      return values?[local ? id : model?.engine ?? id];
    }

    final entries = widget.preview
        ? const [
            ('QWEN_OMNI_PLUS', 'Qwen3.5', '翻译体验更稳定，适合大多数通话'),
            ('DOUBAO', 'Doubao', '适合尝试不同的实时翻译效果'),
            ('OPENAI', 'GPT Live Translate', '适用于海外'),
            ('GEMINI', 'Gemini Live', '适用于海外'),
          ]
        : [
            for (final model in directory?.models ?? [])
              if (options?.isLoading != true)
                (
                  model.id as String,
                  model.name as String,
                  model.subtitle as String,
                ),
          ];
    return NativeTranslationModelPanel(
      busy: qualityBusy || options?.isLoading == true,
      refreshKey: ValueKey(
        widget.domestic
            ? 'domestic-model-refresh'
            : 'translation-model-refresh',
      ),
      onClose: () {
        if (_current) Navigator.pop(context);
      },
      onRefresh: qualityBusy
          ? null
          : () {
              if (!_current || !_admittedNow) return;
              if (widget.preview) {
                setState(() => _previewFailure = !_previewFailure);
              } else {
                ref.invalidate(translationDirectoryProvider);
                if (uses('LOCAL_SIP')) {
                  ref.invalidate(domesticTranslationModelQualityProvider);
                }
                if (uses('BACKEND_WEBRTC')) {
                  ref.invalidate(
                    translationModelQualityProvider(widget.region),
                  );
                }
              }
            },
      children: [
        if (options?.hasError == true)
          TextButton(
            onPressed: () {
              if (_current) ref.invalidate(translationDirectoryProvider);
            },
            child: const Text('翻译配置加载失败，点击重试'),
          ),
        if (!admitted) const Text('当前位置或账号已变化，请关闭后重新选择模型'),
        if (widget.preview) const Text('MOCK · 合成倍率与质量样本，刷新切换失败状态'),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NativeTranslationModelOption(
              key: ValueKey(
                '${widget.domestic ? 'domestic' : 'translation'}-model-${entry.$1}',
              ),
              name: entry.$2,
              subtitle:
                  !widget.preview &&
                      !const {
                        'QWEN',
                        'DOUBAO',
                        'OPENAI',
                        'GEMINI',
                      }.contains(directory?.model(entry.$1)?.engine)
                  ? '当前 App 暂不支持该模型的通话协议'
                  : !widget.preview && !models.contains(entry.$1)
                  ? '当前地区不可用'
                  : entry.$3,
              recommended: directory?.model(entry.$1)?.recommended ?? false,
              selected: admitted && selected == entry.$1,
              multiplier: directory?.model(entry.$1)?.multiplier,
              sample:
                  (widget.preview &&
                          !overseasModelLabels.containsKey(entry.$1)) ||
                      (!widget.preview &&
                          (!models.contains(entry.$1) ||
                              !translationModelSupported(
                                directory!.model(entry.$1)!,
                                overseas: !widget.domestic,
                              )))
                  ? const TranslationModelSample.unavailable()
                  : sample(entry.$1),
              available:
                  (widget.preview &&
                      overseasModelLabels.containsKey(entry.$1)) ||
                  (admitted &&
                      models.contains(entry.$1) &&
                      translationModelSupported(
                        directory!.model(entry.$1)!,
                        overseas: !widget.domestic,
                      )),
              onSelect:
                  !admitted ||
                      (widget.preview &&
                          !overseasModelLabels.containsKey(entry.$1)) ||
                      (!widget.preview &&
                          (!models.contains(entry.$1) ||
                              !translationModelSupported(
                                directory!.model(entry.$1)!,
                                overseas: !widget.domestic,
                              )))
                  ? null
                  : () {
                      if (_current && _admittedNow) {
                        Navigator.pop(context, entry.$1);
                      }
                    },
            ),
          ),
      ],
    );
  }
}
