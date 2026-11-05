import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/invite_providers.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../widgets/invite_activity_card.dart';
import '../widgets/invite_rules_sheet.dart';
import 'invite_records_route.dart';
import 'invite_page.dart';

class InviteActivityRoute extends ConsumerStatefulWidget {
  const InviteActivityRoute({super.key, required this.title});
  final String title;
  @override
  ConsumerState<InviteActivityRoute> createState() =>
      _InviteActivityRouteState();
}

class _InviteActivityRouteState extends ConsumerState<InviteActivityRoute>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      ref.read(inviteControllerProvider.notifier).refresh();
    }
  }

  Future<void> _push(Widget page) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RouteProviderScope(
        container: ProviderScope.containerOf(context),
        child: page,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteControllerProvider);
    final controller = ref.read(inviteControllerProvider.notifier);
    final activity = state.overview?.activity;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            NativePageHeader(
              title: widget.title,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: activity == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.loading)
                            const CircularProgressIndicator(color: inviteBlue)
                          else ...[
                            Text(
                              state.error.isEmpty ? '活动暂未开放' : state.error,
                              style: const TextStyle(color: inviteMuted),
                            ),
                            TextButton(
                              onPressed: controller.refresh,
                              child: const Text(
                                '刷新',
                                style: TextStyle(color: inviteBlue),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          InviteActivityCard(
                            state: state,
                            onRefresh: controller.refresh,
                            onRules: () => showInviteRules(context, activity),
                            onPoster: controller.canShare
                                ? () => _push(const InvitePage())
                                : null,
                            onRecords: () => _push(const InviteRecordsRoute()),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
