import 'package:flutter/material.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../domain/payment_launcher.dart';

Future<bool> showOriginalApplePriceDialog(
  BuildContext context,
  PlatformProduct product,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => NativeConfirmationDialog(
        title: '确认继续支付？',
        message:
            'Apple 当前价格为 ${product.displayPrice}。确认后继续支付原订单，最终以 Apple 账单为准。',
        dismissLabel: '暂不支付',
        confirmLabel: '确认并支付',
      ),
    ) ==
    true;
