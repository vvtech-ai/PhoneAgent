import 'package:flutter/material.dart';
import '../../domain/call_models.dart';
import '../../domain/call_model_quality.dart';
import 'call_model_latency_pill.dart';
import '../../domain/clone_voice.dart';

class NativeModelCard extends StatelessWidget {
  const NativeModelCard({
    super.key,
    required this.model,
    required this.selected,
    required this.busy,
    required this.onSelect,
    this.onVoices,
    this.quick = false,
    this.reading,
    this.voiceSummary,
    this.membershipHint,
  });
  final CallModel model;
  final String? voiceSummary;
  final String? membershipHint;
  String get _voiceName => voiceSummary ?? model.voiceName;
  bool get _showStatus =>
      !model.available &&
      model.status.isNotEmpty &&
      !(model.status == '当前会员权益不支持该模型' && membershipHint?.isNotEmpty == true);
  final CallModelReading? reading;
  final bool selected, busy, quick;
  final VoidCallback onSelect;
  final VoidCallback? onVoices;

  @override
  Widget build(BuildContext context) => Material(
    color: !model.available
        ? const Color(0xFFF7F7F8)
        : quick && selected
        ? const Color(0x0F2196F3)
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(quick ? 14 : 12),
      side: BorderSide(
        width: quick ? 1.5 : 1,
        color: selected
            ? (quick ? const Color(0xFF2196F3) : const Color(0xFF0A84FF))
            : quick
            ? const Color(0xFFE2E8F0)
            : const Color(0xFFE4E7EC),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Semantics(
          container: true,
          button: true,
          selected: selected,
          enabled: model.available && !busy,
          label: [
            model.name,
            if (model.multiplier != null && model.multiplier! > 0)
              '×${model.multiplier!.toStringAsFixed(1)}',
            if (model.recommended) '推荐',
            if (quick)
              reading == null ||
                      reading!.latencyMs == null &&
                          !reading!.confirmedUnavailable
                  ? '模型延迟暂无数据'
                  : reading!.confirmedUnavailable
                  ? '模型不可用'
                  : '模型延迟${reading!.latencyMs}毫秒',
            if (model.description.isNotEmpty) model.description,
            if (_showStatus) model.status,
            if (membershipHint?.isNotEmpty == true) membershipHint!,
          ].join('，'),
          onTap: model.available && !busy && (quick || !selected)
              ? onSelect
              : null,
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('model-${model.id}'),
            onTap: model.available && !busy && (quick || !selected)
                ? onSelect
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: quick ? 14 : 15,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: quick
                          ? const BoxConstraints()
                          : const BoxConstraints(minHeight: 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                model.name,
                                style: TextStyle(
                                  fontSize: quick ? 15 : 16,
                                  height: quick ? null : 22 / 16,
                                  fontWeight: FontWeight.w600,
                                  color: model.available
                                      ? const Color(0xFF111827)
                                      : const Color(0xFF9B9BA1),
                                ),
                              ),
                              if (model.multiplier != null &&
                                  model.multiplier! > 0)
                                Text(
                                  '×${model.multiplier!.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ),
                              if (quick) CallModelLatencyPill(sample: reading),
                              if (model.recommended)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEBF5FF),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Text(
                                    '推荐',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0A84FF),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (model.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                model.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: model.available
                                      ? const Color(0xFF667085)
                                      : const Color(0xFFAEAEB2),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 22),
                          if (_showStatus)
                            Text(
                              model.status,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFAEAEB2),
                              ),
                            ),
                          if (membershipHint?.isNotEmpty == true)
                            Text(
                              membershipHint!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  NativeModelRadio(
                    selected: selected,
                    enabled: model.available,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onVoices != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F7)),
          ),
          Semantics(
            container: true,
            button: true,
            enabled: !busy && (model.available || selected),
            label:
                '${model.name} 的通话声音${_voiceName.isEmpty ? "" : "，$_voiceName"}，${supportsCloneVoice(model.capabilityProvider) ? "支持系统音色和声音克隆" : "支持系统音色"}',
            onTap: !busy && (model.available || selected) ? onVoices : null,
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('voices-${model.id}'),
              onTap: !busy && (model.available || selected) ? onVoices : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            supportsCloneVoice(model.capabilityProvider)
                                ? '支持系统音色和声音克隆'
                                : '支持系统音色',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0A84FF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * .45,
                          ),
                          child: Text(
                            _voiceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                        const Text(
                          ' ›',
                          style: TextStyle(
                            fontSize: 20,
                            height: 27 / 20,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class NativeModelRadio extends StatelessWidget {
  const NativeModelRadio({
    super.key,
    required this.selected,
    this.enabled = true,
  });
  final bool selected, enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
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
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0A84FF),
              ),
            )
          : null,
    ),
  );
}
