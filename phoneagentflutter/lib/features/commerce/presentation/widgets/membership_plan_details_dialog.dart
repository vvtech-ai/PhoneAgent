import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import 'membership_entitlement_sections.dart';

/// Read-only plan details use the same frame as membership payment dialogs.
class MembershipPlanDetailsDialog extends StatelessWidget {
  const MembershipPlanDetailsDialog({super.key, required this.membership});
  final MembershipCurrent membership;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      key: const ValueKey('membership-plan-details-surface'),
      width: 360,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '套餐明细',
              style: TextStyle(
                fontSize: 21,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202329),
              ),
            ),
            const SizedBox(height: 22),
            Flexible(
              child: SingleChildScrollView(
                child: MembershipEntitlementSections(membership: membership),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
