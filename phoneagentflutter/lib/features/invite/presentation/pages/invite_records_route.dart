import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/invite_providers.dart';
import 'invite_records_page.dart';

class InviteRecordsRoute extends ConsumerWidget {
  const InviteRecordsRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(inviteRecordsControllerProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: InviteRecordsPage(
          state: ref.watch(inviteRecordsControllerProvider),
          quota:
              ref.watch(inviteControllerProvider).overview?.activity?.quota ??
              0,
          onBack: () => Navigator.pop(context),
          onRefresh: controller.refresh,
          onLoadNext: controller.loadNext,
        ),
      ),
    );
  }
}
