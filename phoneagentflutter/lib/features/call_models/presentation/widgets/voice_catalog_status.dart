import 'package:flutter/material.dart';
import '../controller/call_model_controller.dart';

/// Catalog facts only; retry stays an explicit user action.
class VoiceCatalogStatus extends StatelessWidget {
  const VoiceCatalogStatus({
    super.key,
    required this.state,
    required this.onRetry,
    this.emptyOnly = false,
  });
  final CallModelState state;
  final VoidCallback onRetry;
  final bool emptyOnly;

  @override
  Widget build(BuildContext context) {
    final noVoices = state.voices?.voices.isEmpty ?? true;
    final error = state.voiceError.isNotEmpty;
    final loading = state.voiceLoading && noVoices;
    final empty = noVoices && !state.voiceLoading && !error;
    if (emptyOnly ? !empty : !error && !loading) {
      return const SizedBox.shrink();
    }
    final message = emptyOnly
        ? '音色列表暂未加载成功，请稍后重试。'
        : error
        ? state.voiceError
        : '加载中...';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 18 / 13,
              color: error || emptyOnly
                  ? const Color(0xFFE14D46)
                  : const Color(0xFF6E6E73),
            ),
          ),
          if (!loading || error)
            TextButton(
              onPressed: state.voiceLoading || state.voiceSaving
                  ? null
                  : onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
