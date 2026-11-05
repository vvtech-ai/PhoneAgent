import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/native_notice.dart';
import '../../../../core/design/page_route_visibility.dart';
import '../../../../core/network/account_session.dart';
import '../../../auth/presentation/controller/auth_providers.dart';
import '../../../commerce/data/device_commerce_legal_document.dart';
import '../../../account_cancellation/presentation/cancellation_controller.dart';
import '../../../account_cancellation/domain/account_cancellation.dart';
import '../../../account_cancellation/presentation/cancellation_providers.dart';
import '../../../account_cancellation/presentation/cancellation_verification_page.dart';
import '../widgets/account_confirmation_dialog.dart';
import 'account_page.dart';

class AccountRoute extends ConsumerStatefulWidget {
  const AccountRoute({super.key});
  @override
  ConsumerState<AccountRoute> createState() => _AccountRouteState();
}

class _AccountRouteState extends ConsumerState<AccountRoute> {
  bool _confirming = false, _busy = false;
  CancellationController? _flow;
  AccountCredentials? _owner;
  void Function()? _releaseInvalidationGuard;
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _noticeOwner = Object();
  PageRouteVisibilityObserver? _visibility;
  ModalRoute<dynamic>? _page;
  bool get _current => mounted && ModalRoute.of(context)?.isCurrent == true;
  bool get _sameOwner =>
      mounted &&
      _owner?.sameLogin(
            ref.read(sessionControllerProvider.notifier).credentials,
          ) ==
          true;

  @override
  void initState() {
    super.initState();
    _code.addListener(_codeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _page = ModalRoute.of(context);
    final observer = context
        .dependOnInheritedWidgetOfExactType<PageRouteVisibilityScope>()
        ?.observer;
    if (identical(observer, _visibility)) return;
    _visibility?.removeListener(_visibilityChanged);
    _visibility = observer;
    observer?.addListener(_visibilityChanged);
  }

  void _visibilityChanged() {
    if (!identical(_visibility?.currentPage, _page)) {
      dismissNativeNotice(owner: _noticeOwner);
      _codeFocus.unfocus();
    }
  }

  void _codeChanged() {
    final state = _flow?.snapshot;
    if (!_current ||
        !_sameOwner ||
        _busy ||
        _confirming ||
        state == null ||
        state.busy ||
        state.unknown ||
        state.result != null ||
        state.delivery == null ||
        !_code.value.composing.isCollapsed ||
        !RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      return;
    }
    // _submit locks synchronously before awaiting. Selection/autofill repeats
    // cannot create a second verification for this input.
    unawaited(_submit());
  }

  void _notice(String message) {
    final flow = _flow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _sameOwner && identical(_flow, flow)) {
        dismissNativeNotice(owner: _noticeOwner);
        showNativeNotice(context, message, owner: _noticeOwner);
      }
    });
  }

  void _focusCode() {
    final flow = _flow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current &&
          _sameOwner &&
          identical(_flow, flow) &&
          flow != null &&
          !_busy &&
          !flow.snapshot.busy &&
          !flow.snapshot.unknown &&
          flow.snapshot.result == null) {
        _codeFocus.requestFocus();
      }
    });
  }

  Future<void> _delete() async {
    if (!_current || _confirming || _busy) return;
    final session = ref.read(sessionControllerProvider.notifier);
    _owner = session.credentials;
    if (_owner == null) return;
    setState(() => _busy = true);
    try {
      // Entry consent is local and must not depend on network or recovery storage.
      _confirming = true;
      final confirmed = await showAccountEntryConfirmation(
        context,
        ref.read(sessionControllerProvider).session?.phone ?? '',
      );
      _confirming = false;
      if (!mounted || confirmed != true || !_current || !_sameOwner) return;
      final coordinator = ref.read(cancellationCoordinatorProvider);
      final confirmedData = await coordinator.prepare(
        isCurrent: () => _current && _sameOwner,
      );
      if (!mounted || !_current || !_sameOwner) return;
      final flow = coordinator.begin(
        confirmedData,
        isCurrent: () => _sameOwner,
      );
      _flow = flow;
      var previousNotice = '';
      flow.addListener((state) {
        if (!mounted || !identical(_flow, flow)) return;
        setState(() {});
        if (state.notice != previousNotice) {
          previousNotice = state.notice;
          if (state.notice.isNotEmpty) _notice(state.notice);
        }
      }, fireImmediately: false);
      setState(() {});
      await flow.send();
    } catch (error) {
      if (mounted && _current && _sameOwner) {
        _notice(cancellationNotice(error, '无法准备注销验证，请稍后重试'));
      }
    } finally {
      _confirming = false;
      if (mounted) setState(() => _busy = false);
      _focusCode();
    }
  }

  Future<void> _resend() async {
    final flow = _flow;
    if (flow == null ||
        !_current ||
        !_sameOwner ||
        _busy ||
        flow.snapshot.busy ||
        flow.snapshot.unknown ||
        flow.snapshot.result != null ||
        flow.snapshot.cooldown > 0) {
      return;
    }
    setState(() => _busy = true);
    final previous = flow.snapshot.delivery;
    try {
      await flow.send();
      if (_current &&
          _sameOwner &&
          identical(_flow, flow) &&
          !identical(previous, flow.snapshot.delivery)) {
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _focusCode();
    }
  }

  Future<void> _submit() async {
    final flow = _flow;
    if (flow == null ||
        !_current ||
        _busy ||
        _confirming ||
        !_sameOwner ||
        flow.snapshot.busy) {
      return;
    }
    if (!flow.snapshot.unknown &&
        flow.snapshot.result == null &&
        (!_code.value.composing.isCollapsed ||
            !RegExp(r'^\d{6}$').hasMatch(_code.text))) {
      return;
    }
    setState(() => _busy = true);
    final exit = ref.read(cancellationExitControllerProvider);
    Object? exitToken;
    var awaitingLogin = false;
    try {
      if (flow.snapshot.unknown) {
        _releaseInvalidationGuard ??= ref
            .read(sessionControllerProvider.notifier)
            .deferInvalidationForCancellation();
        exitToken = exit.begin(_owner!, flow.snapshot);
        await flow.recover();
      } else if (flow.snapshot.result == null) {
        await flow.verify(_code.text);
        if (!mounted || !_sameOwner || !_current) return;
        final verification = flow.snapshot.verification;
        if (verification == null) return;
        _code.clear();
        _codeFocus.unfocus();
        _confirming = true;
        final confirmed = await showAccountConfirmation(
          context,
          ref.read(sessionControllerProvider).session?.phone ?? '',
          confirmation: verification.confirmation,
          openAgreement: () async {
            try {
              await const DeviceCommerceLegalDocument().open(
                accountCancellationAgreementUrl,
              );
            } catch (_) {
              if (mounted && _sameOwner && identical(_flow, flow)) {
                showNativeNotice(
                  context,
                  '暂时无法打开协议，请稍后重试',
                  owner: _noticeOwner,
                );
              }
            }
          },
        );
        _confirming = false;
        if (!mounted || !_sameOwner || !_current || confirmed != true) return;
        _releaseInvalidationGuard ??= ref
            .read(sessionControllerProvider.notifier)
            .deferInvalidationForCancellation();
        exitToken = exit.begin(_owner!, flow.snapshot);
        await flow.submit();
      }
      if (mounted && _sameOwner && flow.snapshot.result?.accepted == true) {
        exitToken ??= exit.begin(_owner!, flow.snapshot);
        exit.accepted(exitToken);
        awaitingLogin = true;
        await _finish(exitToken);
      }
    } catch (error) {
      if (mounted && _current && _sameOwner) {
        _notice(cancellationNotice(error, '注销操作未完成，请重试'));
      }
    } finally {
      if (!awaitingLogin && exitToken != null) exit.fail(exitToken);
      if (awaitingLogin ||
          !mounted ||
          !flow.mounted ||
          !flow.snapshot.unknown) {
        _releaseInvalidationGuard?.call();
        _releaseInvalidationGuard = null;
      }
      _confirming = false;
      if (mounted &&
          _sameOwner &&
          identical(_flow, flow) &&
          !flow.snapshot.unknown &&
          flow.snapshot.result == null) {
        _code.clear();
        flow.discardVerification();
      }
      if (mounted) setState(() => _busy = false);
      _focusCode();
    }
  }

  Future<void> _finish(Object exitToken) async {
    final exit = ref.read(cancellationExitControllerProvider);
    dismissNativeNotice(owner: _noticeOwner);
    final session = ref.read(sessionControllerProvider.notifier);
    final navigator = Navigator.of(context);
    ref.read(cancellationSubmittedNoticeProvider.notifier).state = true;
    session.blockBusinessForCancellation();
    try {
      await session.signOut();
      if (navigator.mounted && session.mounted && session.isSignedOut) {
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (_) {
      exit.fail(exitToken);
      // Root auth gate retains the business block and offers local cleanup retry.
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
    }
  }

  void _back() {
    if (!_current || _busy || _confirming) return;
    final state = _flow?.snapshot;
    if (state?.busy == true ||
        state?.unknown == true ||
        state?.result != null) {
      return;
    }
    if (_flow != null) {
      dismissNativeNotice(owner: _noticeOwner);
      _codeFocus.unfocus();
      _flow!.dispose();
      _flow = null;
      _code.clear();
      setState(() {});
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _releaseInvalidationGuard?.call();
    _visibility?.removeListener(_visibilityChanged);
    dismissNativeNotice(owner: _noticeOwner);
    _flow?.dispose();
    _code.removeListener(_codeChanged);
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, (_, __) {
      if (_owner != null && !_sameOwner) {
        dismissNativeNotice(owner: _noticeOwner);
        _codeFocus.unfocus();
      }
    });
    ref.watch(cancellationCoordinatorProvider);
    final flow = _flow;
    if (flow == null) {
      return AccountPage(
        onDelete: _busy ? null : _delete,
        onBack: _busy ? null : _back,
      );
    }
    final state = flow.snapshot;
    return CancellationVerificationPage(
      state: state,
      code: _code,
      focusNode: _codeFocus,
      onSend: _busy || state.busy || state.unknown || state.cooldown > 0
          ? null
          : _resend,
      onRecover: _busy || state.busy ? null : _submit,
      onBack: _busy || state.busy || state.unknown || state.result != null
          ? null
          : _back,
    );
  }
}
