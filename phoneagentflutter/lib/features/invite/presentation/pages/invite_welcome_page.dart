import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/invite_registration_providers.dart';
import '../../../auth/presentation/controller/auth_providers.dart';
import '../controller/invite_welcome_controller.dart';
import '../widgets/invite_welcome_content.dart';

typedef InviteWelcomeEntry = ({String code, int entryId});

final inviteWelcomeProvider = StateNotifierProvider.autoDispose
    .family<InviteWelcomeController, InviteWelcomeState, InviteWelcomeEntry>((
      ref,
      entry,
    ) {
      final controller = InviteWelcomeController(
        ref.watch(inviteResolverProvider),
        entry.code,
        allowBusinessFailure:
            kIsWeb || defaultTargetPlatform != TargetPlatform.android,
      );
      controller.load();
      return controller;
    });

class InviteWelcomePage extends ConsumerStatefulWidget {
  const InviteWelcomePage({required this.code, this.entryId = 0, super.key});
  final String code;
  final int entryId;
  @override
  ConsumerState<InviteWelcomePage> createState() => _InviteWelcomePageState();
}

class _InviteWelcomePageState extends ConsumerState<InviteWelcomePage>
    with WidgetsBindingObserver {
  InviteWelcomeEntry get _entry => (code: widget.code, entryId: widget.entryId);
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
    if (state == AppLifecycleState.resumed) {
      ref.read(inviteWelcomeProvider(_entry).notifier).load();
    }
  }

  void _login() {
    ref.read(authControllerProvider.notifier).useReferral(widget.code);
    ref.read(pendingInviteProvider.notifier).continueLogin();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _login();
    },
    child: InviteWelcomeContent(
      code: widget.code,
      state: ref.watch(inviteWelcomeProvider(_entry)),
      onBack: _login,
      onContinue: _login,
      onRetry: () => ref.read(inviteWelcomeProvider(_entry).notifier).load(),
    ),
  );
}
