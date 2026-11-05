import 'package:flutter/material.dart';
import '../../../home/domain/home_config.dart';

class ContactSkillsSheet extends StatelessWidget {
  const ContactSkillsSheet({
    super.key,
    required this.contactName,
    required this.cards,
    required this.loading,
    required this.preview,
    required this.onClose,
    required this.onSelect,
    this.error = '',
    this.onRetry,
  });
  final String contactName;
  final List<HomeCard> cards;
  final bool loading, preview;
  final String error;
  final VoidCallback? onRetry;
  final VoidCallback onClose;
  final ValueChanged<HomeCard> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D4DA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择 Skill',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111318),
                      letterSpacing:
                          .5 * MediaQuery.textScalerOf(context).scale(21) / 21,
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  label: '关闭Skill选择',
                  button: true,
                  onTap: onClose,
                  excludeSemantics: true,
                  child: IconButton(
                    tooltip: '关闭Skill选择',
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1,
                        color: Color(0xFF68707D),
                        letterSpacing:
                            .5 *
                            MediaQuery.textScalerOf(context).scale(28) /
                            28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              contactName.trim().isEmpty ? '当前联系人' : contactName,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF747B88),
                letterSpacing:
                    .5 * MediaQuery.textScalerOf(context).scale(13) / 13,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Divider(height: 1, thickness: 1, color: Color(0x1A3C3C43)),
          ),
          if (preview)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('MOCK · 仅演练选择，不向 Agent 发送联系人'),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            error,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9298A3),
                            ),
                          ),
                          TextButton(
                            onPressed: loading ? null : onRetry,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  if (cards.isEmpty && error.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        loading ? '正在获取可用 Skill…' : '暂无可用 Skill',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9298A3),
                          letterSpacing:
                              .5 *
                              MediaQuery.textScalerOf(context).scale(14) /
                              14,
                        ),
                      ),
                    ),
                  for (final card in cards) ...[
                    _SkillRow(card: card, enabled: true, onSelect: onSelect),
                    const Divider(
                      height: .5,
                      thickness: .5,
                      color: Color(0xFFE4E6EB),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.card,
    required this.onSelect,
    required this.enabled,
  });
  final HomeCard card;
  final bool enabled;
  final ValueChanged<HomeCard> onSelect;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: enabled,
    label: [
      card.title,
      card.subtitle,
    ].where((value) => value.isNotEmpty).join('，'),
    onTap: enabled ? () => onSelect(card) : null,
    excludeSemantics: true,
    child: InkWell(
      onTap: enabled ? () => onSelect(card) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15171B),
                      letterSpacing:
                          .5 * MediaQuery.textScalerOf(context).scale(16) / 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8B919B),
                      letterSpacing:
                          .5 * MediaQuery.textScalerOf(context).scale(13) / 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '›',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF8C939E),
                letterSpacing:
                    .5 * MediaQuery.textScalerOf(context).scale(24) / 24,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
