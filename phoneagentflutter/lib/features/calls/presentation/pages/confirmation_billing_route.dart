import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/confirmation_billing_providers.dart';
import '../../domain/confirmation_billing.dart';
import '../../../conversation/domain/call_confirmation.dart';
import '../../../conversation/presentation/widgets/call_confirmation_card.dart';
import '../widgets/confirmation_billing_notice.dart';

class ConfirmationBillingRoute extends ConsumerWidget {
  const ConfirmationBillingRoute({
    super.key,
    required this.request,
    required this.confirmation,
    this.executable = false,
  });
  final ConfirmationBillingRequest request;
  final CallConfirmation confirmation;
  final bool executable;
  @override
  Widget build(BuildContext context, WidgetRef ref) => CallConfirmationCard(
    confirmation: confirmation,
    billing: ref
        .watch(confirmationBillingProvider(request))
        .when(
          data: (snapshot) => ConfirmationBillingNotice(
            key: ValueKey(request.identity),
            snapshot: snapshot,
            recipients: confirmation.recipientCount,
          ),
          loading: () =>
              const Text('正在读取计费说明…', style: TextStyle(fontSize: 10)),
          error: (_, __) => TextButton(
            onPressed: () =>
                ref.invalidate(confirmationBillingProvider(request)),
            child: const Text('计费说明读取失败，点击重试', style: TextStyle(fontSize: 10)),
          ),
        ),
  );
}
