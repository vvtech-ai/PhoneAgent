import 'package:flutter/material.dart';
import '../controller/translation_history_controller.dart';
import '../widgets/translation_history_load_state.dart';

class TranslationHistoryPage extends StatelessWidget {
  const TranslationHistoryPage({
    super.key,
    required this.state,
    required this.onClose,
    required this.onRetry,
    this.recording,
  });
  final TranslationHistoryState state;
  final VoidCallback onClose, onRetry;
  final Widget? recording;
  static const background = Color(0xFFF4F7FB);
  @override
  Widget build(BuildContext context) {
    final content = state.content;
    if (content == null) {
      return ColoredBox(
        color: background,
        child: TranslationHistoryLoadState(
          loading: state.loading,
          failed: state.failed,
          closeButton: _closeButton(context),
          onRetry: onRetry,
        ),
      );
    }
    final recordingSection = content.recordingAvailable
        ? recording ??
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Text(
                  '当前入口未装配录音播放与保存',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollRecording =
            constraints.maxHeight < 700 &&
            MediaQuery.textScalerOf(context).scale(14) > 21;
        return ColoredBox(
          color: background,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      content.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        letterSpacing: 0,
                                        fontWeight: FontWeight.w700,
                                        height: 34 / 28,
                                        color: Color(0xFF111111),
                                      ),
                                    ),
                                  ),
                                  if (content.phone.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          content.phone,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 18 / 15,
                                            letterSpacing: 0,
                                            color: Color(0xFF111111),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _closeButton(context),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                content.time,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 17 / 14,
                                  letterSpacing: 0,
                                  color: Color(0xFF777777),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              content.duration,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 17 / 14,
                                letterSpacing: 0,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (state.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (state.failed)
                    TextButton(
                      key: const ValueKey('retry-translation'),
                      onPressed: onRetry,
                      child: const Text('记录加载失败，点击重试'),
                    ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(
                        top: 18,
                        bottom: recordingSection != null && !scrollRecording
                            ? 148
                            : 28,
                      ),
                      children: [
                        if (content.rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(
                              child: Text(
                                '暂无有效字幕',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 17 / 14,
                                  letterSpacing: 0,
                                  color: Color(0xFF98A2B3),
                                ),
                              ),
                            ),
                          ),
                        for (final row in content.rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _bubble(row),
                          ),
                        if (scrollRecording && recordingSection != null)
                          recordingSection,
                      ],
                    ),
                  ),
                ],
              ),
              if (!scrollRecording && recordingSection != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      IgnorePointer(
                        child: Container(
                          key: const ValueKey('translation-recording-scrim'),
                          height: 144,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, .55, 1],
                              colors: [
                                Color(0x00F4F7FB),
                                Color(0xEBF4F7FB),
                                background,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: recordingSection,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bubble(TranslationRow row) => Align(
    alignment: row.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: .82,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: row.mine ? const Color(0xFF1677E8) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(row.mine ? 22 : 6),
            bottomRight: Radius.circular(row.mine ? 6 : 22),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (row.primary.isNotEmpty)
              Semantics(
                container: true,
                child: SelectableText(
                  row.primary,
                  semanticsLabel: row.primary,
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 0,
                    height: 23 / 16,
                    color: row.mine ? Colors.white : const Color(0xFF111111),
                  ),
                ),
              ),
            if (row.secondary.isNotEmpty) ...[
              if (row.primary.isNotEmpty) const SizedBox(height: 7),
              Semantics(
                container: true,
                child: SelectableText(
                  row.secondary,
                  semanticsLabel: row.secondary,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0,
                    height: 20 / 14,
                    color: row.mine
                        ? const Color(0xFFD9EBFF)
                        : const Color(0xFF777777),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _closeButton(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: true,
    label: '关闭翻译记录',
    onTap: () => _close(context),
    excludeSemantics: true,
    child: IconButton(
      key: const ValueKey('close-translation'),
      tooltip: '关闭翻译记录',
      onPressed: () => _close(context),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Text(
        '×',
        style: TextStyle(
          fontSize: 32,
          letterSpacing: 0,
          height: 34 / 32,
          fontWeight: FontWeight.w300,
          color: Color(0xFF111111),
        ),
      ),
    ),
  );

  void _close(BuildContext context) {
    if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
      onClose();
    }
  }
}
