import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/native_notice.dart';
import '../../../auth/presentation/controller/auth_providers.dart';
import '../../../auth/presentation/controller/session_controller.dart';
import '../widgets/account_confirmation_dialog.dart';
import 'account_page.dart';

class AccountRoute extends ConsumerStatefulWidget {
  const AccountRoute({super.key});
  @override
  ConsumerState<AccountRoute> createState() => _AccountRouteState();
}

class _AccountRouteState extends ConsumerState<AccountRoute> {
  bool _confirming = false;
  bool _busy = false;
  bool get _current => mounted && ModalRoute.of(context)?.isCurrent == true;

  Future<void> _delete() async {
    if (!_current || _confirming || _busy) return;
    final session = ref.read(sessionControllerProvider.notifier);
    final owner = session.credentials;
    final phone = ref.read(sessionControllerProvider).session?.phone ?? '';
    _confirming = true;
    final confirmed = await showAccountConfirmation(context, phone);
    if (!mounted) return;
    _confirming = false;
    if (confirmed != true || !_current) return;
    if (owner == null ||
        !session.mounted ||
        !identical(session, ref.read(sessionControllerProvider.notifier)) ||
        !owner.sameLogin(session.credentials)) {
      showNativeNotice(context, '账号状态已变化，请重新进入账号页面');
      return;
    }
    setState(() => _busy = true);
    try {
      // Native deleteAccount only signs out; it does not delete user data.
      await session.signOut();
      if (mounted &&
          _current &&
          session.mounted &&
          ref.read(sessionControllerProvider).phase == SessionPhase.signedOut) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted && _current) showNativeNotice(context, '操作未完成，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountPage(
    onDelete: _busy ? null : _delete,
    onBack: _busy
        ? null
        : () {
            if (_current && !_confirming) Navigator.of(context).pop();
          },
  );
}
