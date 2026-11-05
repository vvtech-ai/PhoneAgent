import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';

class MembershipOfferHeader extends StatelessWidget {
  const MembershipOfferHeader({
    super.key,
    required this.selectedLevel,
    required this.currentLevel,
    required this.concurrentLimit,
  });
  final String selectedLevel;
  final String? currentLevel;
  final Object? concurrentLimit;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          selectedLevel == 'FREE'
              ? '免费用户'
              : '${membershipName(selectedLevel)}会员',
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7F8590),
          ),
        ),
      ),
      if (currentLevel == selectedLevel)
        Container(
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            '当前权益',
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: Color(0xFF1677FF),
            ),
          ),
        ),
    ],
  );
}
