import 'package:flutter/material.dart';
import '../../../../core/design/native_action_style.dart';

/// Shared native clone label/cost; callers own authorization and route guards.
class ClonePointsButton extends StatelessWidget {
  const ClonePointsButton({
    super.key,
    required this.onPressed,
    this.pricePoints,
    this.buttonKey,
    this.minimumWidth = 145,
    this.horizontalPadding = 14,
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: NativeActionStyle.decoration(enabled: onPressed != null),
    child: FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      style: NativeActionStyle.buttonStyle(context).copyWith(
        minimumSize: WidgetStatePropertyAll(Size(minimumWidth, 50)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14),
        ),
      ),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '声音克隆',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 20 / 15,
            ),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 20 / 15,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
