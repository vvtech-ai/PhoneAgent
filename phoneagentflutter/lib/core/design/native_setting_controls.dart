import 'package:flutter/material.dart';

class NativeSettingChoice extends StatelessWidget {
  const NativeSettingChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    enabled: onTap != null,
    selected: selected,
    onTap: onTap,
    excludeSemantics: true,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        backgroundColor: selected
            ? const Color(0xFFEFF6FF)
            : const Color(0xEBFFFFFF),
        foregroundColor: selected
            ? const Color(0xFF0A84FF)
            : const Color(0xFF6E6E73),
        side: BorderSide(
          color: selected ? const Color(0x800A84FF) : const Color(0x143C3C43),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class NativeSettingCard extends StatelessWidget {
  const NativeSettingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.titleColor = const Color(0xFF111111),
    this.isAction = false,
    this.homeLayout = false,
  });
  final Color titleColor;
  final bool isAction, homeLayout;
  final String title, subtitle, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      container: true,
      button: isAction || onTap != null,
      enabled: isAction || onTap != null ? onTap != null : null,
      label: [
        title,
        subtitle,
        value.replaceAll('›', '').trim(),
      ].where((text) => text.isNotEmpty).join('，'),
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xCCFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(24)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xC7FFFFFF))),
          boxShadow: [
            BoxShadow(
              color: Color(0x14101114),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          height: (homeLayout ? 23 : 20) / 16,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 19 / 13,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                      ],
                    ],
                  );
                  const style = TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6E6E73),
                  );
                  final right = Text(value, style: style);
                  if (value.isEmpty) return left;
                  final measure = TextPainter(
                    text: TextSpan(text: value, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final stacked = homeLayout
                      ? measure.width > constraints.maxWidth - 60
                      : measure.width > constraints.maxWidth * .45 ||
                            MediaQuery.textScalerOf(context).scale(13) > 19.5;
                  measure.dispose();
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        left,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: right),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 12),
                      right,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
