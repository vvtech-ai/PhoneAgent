import 'package:flutter/material.dart';
import '../../domain/call_evaluation.dart';
import '../controller/call_evaluation_controller.dart';

class CallEvaluationCard extends StatelessWidget {
  const CallEvaluationCard({
    super.key,
    required this.state,
    required this.onRate,
  });
  final CallEvaluationState state;
  final ValueChanged<CallRating> onRate;
  @override
  Widget build(BuildContext context) {
    final evaluation = state.evaluation;
    if (evaluation?.visible != true) return const SizedBox.shrink();
    return Container(
      width: 198,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _value('使用模型', evaluation!.modelName),
          const SizedBox(height: 6),
          _value('平均时延', evaluation.latencyText),
          const SizedBox(height: 9),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEF2F7)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '评价',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF718096),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _button(
                    CallRating.good,
                    '好评',
                    Icons.thumb_up_outlined,
                    evaluation.rating,
                  ),
                  const SizedBox(width: 6),
                  _button(
                    CallRating.bad,
                    '差评',
                    Icons.thumb_down_outlined,
                    evaluation.rating,
                  ),
                ],
              ),
            ],
          ),
          if (state.error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.error,
              style: TextStyle(color: const Color(0xFFD92D20), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _value(String label, String value) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF718096),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    ],
  );
  Widget _button(
    CallRating rating,
    String label,
    IconData icon,
    CallRating? current,
  ) {
    final selected = current == rating;
    final enabled = !state.saving;
    void rate() {
      if (enabled) onRate(rating);
    }

    return Semantics(
      container: true,
      label: label,
      button: true,
      enabled: enabled,
      selected: selected,
      onTap: enabled ? rate : null,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: enabled ? rate : null,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 30,
                height: 29,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE6F3FF)
                      : const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFA7D4FF)
                        : const Color(0xFFE8E8E9),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? const Color(0xFF0A84FF)
                      : const Color(0xFF344054),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
