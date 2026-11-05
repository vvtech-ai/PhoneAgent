import 'package:flutter/material.dart';
import '../../../../core/design/native_card_style.dart';

/// C22 successful empty state; loading and failures remain owned by the page.
class CommerceEmptyOrders extends StatelessWidget {
  const CommerceEmptyOrders({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: NativeCardStyle.decoration,
    child: const Text(
      '暂无订单',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF92969E)),
    ),
  );
}
