import 'package:flutter/material.dart';
import '../../../../core/design/native_loading_overlay.dart';

/// Keeps the original checkout text and mask while sharing the loading surface.
class PurchaseLoadingOverlay extends StatelessWidget {
  const PurchaseLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) =>
      const NativeLoadingOverlay(message: '支付处理中…');
}
