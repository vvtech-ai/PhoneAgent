import 'package:flutter/material.dart';

/// Empty success keeps the same six-column structure as an order table.
class CommerceEmptyOrders extends StatelessWidget {
  const CommerceEmptyOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF202020) : Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: dark
                      ? const Color(0xFF333333)
                      : const Color(0xFFEEF0F3),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final label in ['类型', '日期', '金额', '支付渠道', '状态', '操作'])
                  Expanded(
                    flex: label == '支付渠道' ? 3 : 2,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF747982),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text(
              '暂无更多数据',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: dark ? const Color(0xFF666666) : const Color(0xFF92969E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
