import 'package:flutter/material.dart';

/// Reuses the original checkout mask for both membership and Apple points.
class PurchaseLoadingOverlay extends StatelessWidget {
  const PurchaseLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) => const AbsorbPointer(
    child: ColoredBox(
      color: Color(0x55000000),
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('支付处理中…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
