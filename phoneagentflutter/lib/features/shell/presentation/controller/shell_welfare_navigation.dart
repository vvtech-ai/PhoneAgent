import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invite/presentation/pages/invite_activity_route.dart';

/// Welfare owns its navigation scope; the shell only refreshes on return.
Future<void> openShellWelfare(
  BuildContext context, {
  required VoidCallback onReturned,
}) async {
  final container = ProviderScope.containerOf(context);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const InviteActivityRoute(title: '福利'),
      ),
    ),
  );
  if (context.mounted) onReturned();
}
