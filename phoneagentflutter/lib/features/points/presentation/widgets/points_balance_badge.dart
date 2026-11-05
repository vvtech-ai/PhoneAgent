import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/points_presentation.dart';

class PointsBalanceBadge extends StatelessWidget {
  const PointsBalanceBadge({
    super.key,
    required this.balance,
    required this.onOpen,
  });
  final int? balance;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('open-points-wallet'),
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xFFF1F2F4),
      foregroundColor: const Color(0xFF303238),
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    onPressed: onOpen,
    child: Semantics(
      label: '积分余额 ${PointsPresentation.balance(balance)}，打开积分',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/shell/points.svg',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 6),
          Text(
            PointsPresentation.balance(balance),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
