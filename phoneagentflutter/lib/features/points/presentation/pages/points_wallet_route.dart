import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/points_providers.dart';
import 'points_wallet_page.dart';

class PointsWalletRoute extends ConsumerWidget {
  const PointsWalletRoute({super.key, this.ledger = false});
  final bool ledger;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pointsWalletControllerProvider);
    final billing = ledger ? null : ref.watch(pointsBillingProvider);
    final rate = billing != null && !billing.isLoading && !billing.hasError
        ? billing.valueOrNull
        : null;
    final controller = ref.read(pointsWalletControllerProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        bottom: !ledger,
        child: ledger
            ? PointsLedgerPage(
                state: state,
                onBack: () => Navigator.pop(context),
                onRefresh: controller.refresh,
                onLoadNext: controller.loadNext,
              )
            : PointsWalletPage(
                pointsPerMinute: rate,
                state: state,
                onBack: () => Navigator.pop(context),
                onRefresh: () async {
                  ref.invalidate(pointsBillingProvider);
                  await controller.refresh();
                },
                onLedger: () {
                  final container = ProviderScope.containerOf(context);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => UncontrolledProviderScope(
                        container: container,
                        child: const PointsWalletRoute(ledger: true),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
