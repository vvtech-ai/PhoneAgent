import 'package:flutter/material.dart';
import '../../../points/domain/points_presentation.dart';
import 'commerce_display_format.dart';
import 'commerce_widgets.dart';

class MembershipBalanceCard extends StatelessWidget {
  const MembershipBalanceCard({
    super.key,
    required this.availablePoints,
    required this.heldPoints,
    required this.onPoints,
    required this.onLedger,
    this.pointsPerMinute,
    this.todayDailyGrantReceived = false,
    this.todayDailyGrantPoints = 0,
  });
  final int? availablePoints, heldPoints;
  final int? pointsPerMinute;
  final bool todayDailyGrantReceived;
  final int todayDailyGrantPoints;
  final VoidCallback? onPoints;
  final VoidCallback onLedger;

  String get _balanceHint {
    final minutes = availablePoints == null
        ? null
        : PointsPresentation.estimatedMinutes(
            availablePoints!,
            pointsPerMinute: pointsPerMinute,
          );
    final gift =
        availablePoints != null &&
            todayDailyGrantReceived &&
            todayDailyGrantPoints > 0
        ? ' · 今日赠送 ${displayPoints(todayDailyGrantPoints)} 积分已到账'
        : '';
    return '${minutes == null ? '通话时长估算暂不可用' : '约可通话 $minutes 分钟'}$gift';
  }

  @override
  Widget build(BuildContext context) => CommerceCard(
    marginBottom: 0,
    contentPadding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '可用积分',
                style: TextStyle(fontSize: 13, color: Color(0xFF62666F)),
              ),
            ),
            if (onPoints != null)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: const Color(0xFFF1F4F8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: onPoints,
                child: const Text(
                  '+ 购买积分',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const PointsSpark(),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  availablePoints == null
                      ? '—'
                      : displayPoints(availablePoints!),
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _balanceHint,
          style: const TextStyle(fontSize: 11, color: Color(0xFF858991)),
        ),
        const Divider(height: 20, color: Color(0xFFECEEF2)),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            foregroundColor: const Color(0xFF1767CA),
          ),
          onPressed: onLedger,
          child: const Row(
            children: [
              Expanded(child: Text('查看积分流水', style: TextStyle(fontSize: 12))),
              Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ],
    ),
  );
}
