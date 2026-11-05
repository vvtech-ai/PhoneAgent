import 'package:flutter/material.dart';

/// Keeps the full consent and its separate legal link on one fitted line.
class MembershipAgreementLine extends StatelessWidget {
  const MembershipAgreementLine({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onLegal,
  });
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLegal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 3),
    child: Row(
      children: [
        SizedBox(
          width: 16,
          height: 24,
          child: Checkbox(
            value: accepted,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
            side: const BorderSide(color: Color(0xFF858991), width: 1),
            activeColor: const Color(0xFF1677FF),
            onChanged: (value) => onChanged(value == true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '支付即表示你已阅读并同意',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: Color(0xFF6F747D),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onLegal,
                  child: const Text(
                    'PhoneAgent 付费服务协议',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.7,
                      color: Color(0xFF3478F5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
