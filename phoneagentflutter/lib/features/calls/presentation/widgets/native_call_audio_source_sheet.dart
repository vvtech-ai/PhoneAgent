import 'package:flutter/material.dart';
import '../controller/call_presentation.dart';
import 'call_icons.dart';

class NativeCallAudioSourceSheet extends StatelessWidget {
  const NativeCallAudioSourceSheet({
    super.key,
    required this.monitor,
    required this.onSelect,
    required this.onCancel,
    this.preview = false,
  });
  final CallMonitorView monitor;
  final ValueChanged<CallAudioSource> onSelect;
  final VoidCallback onCancel;
  final bool preview;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF626B7B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Semantics(
              header: true,
              child: const Text(
                '发声源',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              preview ? 'MOCK · 只模拟选择，不切换设备音频' : '选择监听声音的播放设备',
              style: const TextStyle(fontSize: 13, color: Color(0xFFAEB2BE)),
            ),
          ),
          for (final source in monitor.sources) _row(source),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: _panel(
              InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(CallAudioSource source) {
    final selected = source == monitor.source;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: source.label,
      onTap: () => onSelect(source),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: _panel(
          InkWell(
            key: ValueKey('source-${source.name}'),
            onTap: () => onSelect(source),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 21,
                        child: FittedBox(
                          child: CallIcons.icon(
                            CallIcons.source(source),
                            color: const Color(0xFFD2D5DD),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      source.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Radio<CallAudioSource>(
                    value: source,
                    groupValue: monitor.source,
                    onChanged: (_) => onSelect(source),
                    fillColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFF4C8DFF)
                          : const Color(0xFF777B85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(Widget child) => Material(
    color: const Color(0xFF252A34),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFF3A4352)),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
