import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import 'membership_plan_details_dialog.dart';

/// Owns only the retained/queued plan presentation, never purchase state.
class MembershipPlanDetailsButton extends StatelessWidget {
  const MembershipPlanDetailsButton({super.key, required this.membership});
  final MembershipCurrent membership;

  @override
  Widget build(BuildContext context) {
    if (membership.retainedEntitlements.isEmpty &&
        membership.queuedEntitlements.isEmpty) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => MembershipPlanDetailsDialog(membership: membership),
      ),
      child: const Text('套餐明细', style: TextStyle(fontSize: 12)),
    );
  }
}
