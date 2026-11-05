import 'package:flutter/material.dart';
import '../../domain/call_models.dart';

class NativeVoiceSelectionRow extends StatelessWidget {
  const NativeVoiceSelectionRow({
    super.key,
    required this.voice,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    this.showPreview = false,
    this.previewLoading = false,
    this.previewPlaying = false,
    this.onPreview,
    this.previewName,
  });
  final CallVoice voice;
  final bool selected, enabled;
  final VoidCallback onSelect;
  final bool showPreview, previewLoading, previewPlaying;
  final VoidCallback? onPreview;
  final String? previewName;

  bool get _canSelect => enabled && !selected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Stack(
        children: [
          Semantics(
            container: true,
            selected: selected,
            button: true,
            enabled: _canSelect,
            label: [
              voice.name,
              if (voice.description.isNotEmpty) voice.description,
            ].join('，'),
            onTap: _canSelect ? onSelect : null,
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('voice-selection:${voice.id}'),
                onTap: _canSelect ? onSelect : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 66),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 1.5,
                              color: selected
                                  ? const Color(0xFF0A84FF)
                                  : enabled
                                  ? const Color(0xFF98A2B3)
                                  : const Color(0xFFD0D5DD),
                            ),
                          ),
                          child: selected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF0A84FF),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voice.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 20 / 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (voice.description.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  voice.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 17 / 12,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showPreview) const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showPreview)
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: Center(child: _preview()),
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(left: 34),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFEAECF0)),
      ),
    ],
  );
  Widget _preview() => Semantics(
    container: true,
    button: true,
    label: previewLoading
        ? '读取${previewName ?? voice.name}试听'
        : previewPlaying
        ? '停止${previewName ?? voice.name}试听'
        : '试听${previewName ?? voice.name}',
    enabled: onPreview != null,
    onTap: onPreview,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPreview ?? () {},
      child: SizedBox(
        width: 48,
        height: 48,
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 38,
            height: 38,
            // Ink belongs to the visible circle, not the larger hit target
            // or the sheet's Material behind it.
            child: Material(
              color: const Color(0xFFF2F7FF),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPreview,
                customBorder: const CircleBorder(),
                splashColor: const Color(0x1F0A84FF),
                highlightColor: const Color(0x140A84FF),
                hoverColor: const Color(0x140A84FF),
                focusColor: const Color(0x1F0A84FF),
                child: Center(
                  child: previewLoading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0A84FF),
                          ),
                        )
                      : Icon(
                          previewPlaying ? Icons.stop : Icons.play_arrow,
                          size: 19,
                          color: onPreview == null
                              ? const Color(0xFF98A2B3)
                              : const Color(0xFF0A84FF),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
