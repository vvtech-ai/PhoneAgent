import 'package:flutter/material.dart';

/// Shared native clone label/cost; callers own authorization and route guards.
class ClonePointsButton extends StatelessWidget {
  const ClonePointsButton({
    super.key,
    required this.onPressed,
    this.pricePoints,
    this.buttonKey,
    this.minimumWidth = 145,
    this.horizontalPadding = 16,
  });
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final int? pricePoints;
  String get priceLabel =>
      pricePoints != null && pricePoints! > 0 ? '$pricePoints' : '—';
  static String semanticLabel(int? price) =>
      price != null && price > 0 ? '声音克隆，$price积分' : '声音克隆，价格暂不可用';
  final double minimumWidth, horizontalPadding;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: buttonKey,
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0A84FF),
      minimumSize: Size(minimumWidth, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 11,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '声音克隆',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✦',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFC400),
              ),
            ),
            SizedBox(width: 5),
            Text(
              priceLabel,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}
