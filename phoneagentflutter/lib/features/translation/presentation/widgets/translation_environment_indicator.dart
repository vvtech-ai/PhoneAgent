import 'package:flutter/material.dart';
import '../../domain/translation_call_environment.dart';

Color translationEnvironmentColor(TranslationEnvironmentState state) =>
    switch (state) {
      TranslationEnvironmentState.pending => const Color(0x80FFFFFF),
      TranslationEnvironmentState.available => const Color(0xFF34C759),
      TranslationEnvironmentState.degraded => const Color(0xFFFF9F0A),
      TranslationEnvironmentState.unavailable => const Color(0xFFFF453A),
      TranslationEnvironmentState.notApplicable => const Color(0x57FFFFFF),
    };

class TranslationEnvironmentIndicator extends StatelessWidget {
  const TranslationEnvironmentIndicator({super.key, required this.environment});
  final TranslationCallEnvironment environment;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 8,
    runSpacing: 4,
    children: [
      _item('网络', environment.network),
      _item('SIP', environment.sip),
      _item('模型', environment.model),
    ],
  );

  Widget _item(String label, TranslationEnvironmentState state) => Semantics(
    label: '$label ${state.label}',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            height: 1.2,
            color: Color(0xC7FFFFFF),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          key: ValueKey('translation-health-$label'),
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: translationEnvironmentColor(state),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    ),
  );
}
