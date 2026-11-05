import 'package:flutter/material.dart';
import '../controller/translation_archive_controller.dart';

class TranslationArchiveStatusView extends StatelessWidget {
  const TranslationArchiveStatusView({
    super.key,
    required this.state,
    required this.onRetry,
  });
  final TranslationArchiveStatus state;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (state.failed) {
      return TextButton.icon(
        key: const Key('translation-archive-retry'),
        onPressed: state.busy ? null : onRetry,
        icon: const Icon(Icons.sync_problem),
        label: const Text('翻译历史同步未完成，点击重试'),
      );
    }
    if (state.busy && state.pending > 0) return const Text('正在同步翻译历史');
    return const SizedBox.shrink();
  }
}
