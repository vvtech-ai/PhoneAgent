import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/confirmation_billing_providers.dart';
import '../../../conversation/domain/batch_confirmation.dart';
import '../../../conversation/presentation/widgets/batch_confirmation_card.dart';
import '../../domain/confirmation_billing.dart';
import '../widgets/confirmation_billing_notice.dart';

class BatchConfirmationBillingRoute extends ConsumerWidget {
  const BatchConfirmationBillingRoute({
    super.key,
    required this.sessionId,
    required this.confirmation,
    this.executable = false,
  });
  final String sessionId;
  final BatchConfirmation confirmation;
  final bool executable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ConfirmationBillingRequest(sessionId, [
      confirmation.billingAlias,
    ], captureCurrent: confirmation.capturesBilling);
    return BatchConfirmationCard(
      confirmation: confirmation,
      billing: ref
          .watch(confirmationBillingProvider(request))
          .when(
            data: (snapshot) => snapshot.modelTitle?.trim().isNotEmpty != true
                ? const SizedBox.shrink()
                : BatchConfirmationPanel(
                    title: '积分说明',
                    status: '未接通不扣',
                    child: ConfirmationBillingNotice(
                      key: ValueKey('$sessionId:${confirmation.billingAlias}'),
                      snapshot: snapshot,
                      recipients: confirmation.recipients.length,
                    ),
                  ),
            loading: () =>
                const Text('正在读取计费说明…', style: TextStyle(fontSize: 10)),
            error: (_, __) => TextButton(
              onPressed: () =>
                  ref.invalidate(confirmationBillingProvider(request)),
              child: const Text('计费说明读取失败，点击重试'),
            ),
          ),
    );
  }
}
