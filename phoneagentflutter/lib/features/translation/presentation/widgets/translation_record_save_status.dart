import 'package:flutter/material.dart';
import '../controller/translation_finished_recorder.dart';

/// Only metadata persistence. Does not report remote archive or settlement.
class TranslationRecordSaveStatus extends StatelessWidget {
  const TranslationRecordSaveStatus({
    super.key,
    required this.state,
    required this.onRetry,
  });
  final TranslationRecordSaveState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.saving) return const Text('正在保存本机翻译记录');
    if (state.failedCount == 0) return const SizedBox.shrink();
    return TextButton.icon(
      key: const Key('translation-record-retry'),
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: Text(state.error),
    );
  }
}
