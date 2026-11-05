import '../../../../app/translation_directory_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_model_selection_providers.dart';
import 'domestic_translation_model_sheet.dart';
import 'native_translation_dial_summary.dart';

class DomesticTranslationDialSummary extends ConsumerStatefulWidget {
  const DomesticTranslationDialSummary({
    super.key,
    required this.enabled,
    required this.languages,
    required this.busy,
    required this.onLanguages,
  });
  final bool enabled, busy;
  final String languages;
  final VoidCallback? onLanguages;
  @override
  ConsumerState<DomesticTranslationDialSummary> createState() =>
      _SummaryState();
}

class _SummaryState extends ConsumerState<DomesticTranslationDialSummary> {
  bool _showing = false;
  Future<void> _openModel() async {
    if (_showing ||
        widget.busy ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _showing = true;
    try {
      await showDomesticTranslationModelSheet(context);
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(selectedTranslationModelProvider);
    final options = ref.watch(translationDirectoryProvider);
    return NativeTranslationDialSummary(
      model: options.isLoading
          ? '模型加载中'
          : options.hasError
          ? '模型加载失败，点击重试'
          : configured?.name ?? '当前位置无可用模型',
      multiplier: configured?.multiplier,
      languages: widget.languages,
      translationEnabled: widget.enabled,
      onLanguages: widget.onLanguages,
      onModel: widget.busy
          ? null
          : () {
              if (options.hasError) {
                ref.invalidate(translationDirectoryProvider);
              } else {
                _openModel();
              }
            },
    );
  }
}
