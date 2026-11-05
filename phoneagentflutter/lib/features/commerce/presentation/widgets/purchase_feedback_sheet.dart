import 'package:flutter/material.dart';
import '../controller/purchase_controller.dart';
import '../payment_attempt_feedback.dart';
import 'commerce_widgets.dart';

class PurchaseFeedbackSheet extends StatelessWidget {
  const PurchaseFeedbackSheet({
    super.key,
    required this.state,
    required this.upgrade,
    required this.onDone,
  });
  final PurchaseState state;
  final bool upgrade;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final feedback = paymentAttemptFeedback(state, upgrade: upgrade);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (feedback.completed)
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Color(0xFF23B678),
              )
            else if (feedback.processing)
              const Icon(Icons.info_outline, size: 64, color: Color(0xFF1677FF))
            else
              const DecoratedBox(
                key: ValueKey('paymentFeedbackAlert'),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF1F1),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Icon(
                    Icons.priority_high,
                    size: 28,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              feedback.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              feedback.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF777C84)),
            ),
            const SizedBox(height: 22),
            CommerceAction('完成', onPressed: onDone),
          ],
        ),
      ),
    );
  }
}
