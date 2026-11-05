import 'package:flutter/material.dart';
import '../../domain/confirmation_billing.dart';

class ConfirmationBillingNotice extends StatelessWidget {
  const ConfirmationBillingNotice({
    super.key,
    required this.snapshot,
    required this.recipients,
  });
  final ConfirmationBillingSnapshot snapshot;
  final int recipients;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          children: [
            _BillingSegment(label: '接通后首分钟', points: snapshot.firstMinute),
            _BillingSegment(label: '之后每 6 秒', points: snapshot.sixSeconds),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            snapshot.footer,
            style: const TextStyle(
              fontSize: 12,
              height: 17 / 12,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        for (final notice in snapshot.notices(recipients))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: notice == '多路积分不足'
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notice,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A4F00),
                      ),
                    ),
                  )
                : Text(
                    notice,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      color: Color(0xFFF29900),
                    ),
                  ),
          ),
      ],
    ),
  );
}

class _BillingSegment extends StatelessWidget {
  const _BillingSegment({required this.label, required this.points});
  final String label;
  final int points;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
      ),
      const SizedBox(width: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8EF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$points积分',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: const TextStyle(
            color: Color(0xFF187A3A),
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}
