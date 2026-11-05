import 'package:flutter/material.dart';
import '../../domain/translation_call_view.dart';
import 'translation_environment_indicator.dart';

class TranslationCallIdentity extends StatelessWidget {
  const TranslationCallIdentity({
    super.key,
    required this.target,
    required this.state,
  });

  final String target;
  final TranslationCallView state;

  @override
  Widget build(BuildContext context) {
    final color = translationEnvironmentColor(state.environment.overall);
    final minutes = (state.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (state.elapsedSeconds % 60).toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          target,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: .5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            state.phaseText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12,
              letterSpacing: .5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$minutes:$seconds',
          style: const TextStyle(
            color: Color(0xAAFFFFFF),
            fontSize: 13,
            letterSpacing: .5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
