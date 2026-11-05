import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../widgets/commerce_widgets.dart';

class PurchasePreviewSheet extends StatelessWidget {
  const PurchasePreviewSheet({
    super.key,
    required this.quote,
    required this.productName,
    required this.displayPrice,
    required this.currentExpiresAt,
    required this.onConfirm,
    this.pointsPurchase = false,
  });
  final CommerceQuote quote;
  final bool pointsPurchase;
  final String productName, displayPrice;
  final DateTime? currentExpiresAt;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D8DD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '确认购买',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(productName),
                    trailing: Text(
                      displayPrice,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Divider(),
                  if (!pointsPurchase && currentExpiresAt != null)
                    ListTile(
                      title: const Text('当前到期日'),
                      subtitle: Text(commerceDate(currentExpiresAt)),
                    ),
                  if (quote.conversionSeconds > 0)
                    ListTile(
                      title: const Text('剩余价值折算会员时长'),
                      subtitle: Text(
                        '${(quote.conversionSeconds / 86400).toStringAsFixed(2)} 天；不退现金',
                      ),
                    ),
                  if (quote.estimatedExpiresAt != null)
                    ListTile(
                      title: const Text('预计新到期日'),
                      subtitle: Text(commerceDate(quote.estimatedExpiresAt)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      pointsPurchase
                          ? '单次购买，积分以支付确认后的服务端到账结果为准。'
                          : '单次购买，不自动续费。权益以支付确认后的服务端结果为准。',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777B84),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          CommerceAction('确认支付', onPressed: onConfirm),
        ],
      ),
    ),
  );
}
