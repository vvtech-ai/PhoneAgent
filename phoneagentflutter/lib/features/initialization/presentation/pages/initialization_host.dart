import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/initialization_providers.dart';
import 'initialization_page.dart';

/// Lives under the authenticated epoch: no parallel shell while onboarding.
class InitializationHost extends ConsumerWidget {
  const InitializationHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(initializationControllerProvider);
    if (state.finished) return child;
    final controller = ref.read(initializationControllerProvider.notifier);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.busy) controller.back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: InitializationPage(
          state: state,
          onBack: controller.back,
          onSkip: controller.skipIdentity,
          onNext: controller.next,
          onRetry: controller.load,
          onName: (value) => controller.edit(name: value),
          onGender: (value) => controller.edit(gender: value),
          onPhone: (value) => controller.edit(phone: value),
          onModel: controller.select,
        ),
      ),
    );
  }
}
