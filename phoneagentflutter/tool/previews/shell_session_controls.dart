import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';

/// Explicit synthetic-only control outside the App's navigator. This cannot be
/// imported by the production entry; ShellPreviewPage owns its in-memory ports.
class ShellSessionControls extends ConsumerWidget {
  const ShellSessionControls({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final session = ref.read(sessionControllerProvider.notifier);
    return Column(
      children: [
        Material(
          color: const Color(0xfffff3cd),
          child: Wrap(
            children: [
              TextButton(
                onPressed: state.phase != SessionPhase.signedIn
                    ? null
                    : () async {
                        final owner = session.credentials;
                        if (owner != null) {
                          await session.replaceToken(
                            owner,
                            'synthetic-refreshed',
                          );
                        }
                      },
                child: const Text('MOCK：刷新令牌'),
              ),
              TextButton(
                onPressed: state.phase != SessionPhase.signedIn
                    ? null
                    : () async {
                        final owner = session.credentials;
                        if (owner != null) await session.rejectSession(owner);
                      },
                child: const Text('MOCK：登录失效'),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
