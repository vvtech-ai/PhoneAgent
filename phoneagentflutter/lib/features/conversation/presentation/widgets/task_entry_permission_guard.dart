import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/agent_context_providers.dart';
import '../../../../core/design/native_business_dialog.dart';
import '../../../../core/design/native_notice.dart';
import '../../domain/tools/conversation_permission.dart';
import '../../domain/tools/conversation_permission_access.dart';

final _admissions = Expando<bool>();

Future<bool> allowTaskMicrophoneEntry(
  BuildContext context,
  bool Function() current,
) async {
  final owner = ModalRoute.of(context) ?? context;
  if (_admissions[owner] == true) return false;
  _admissions[owner] = true;
  try {
    return await _allowTaskMicrophoneEntry(context, current);
  } finally {
    _admissions[owner] = false;
  }
}

Future<bool> _allowTaskMicrophoneEntry(
  BuildContext context,
  bool Function() current,
) async {
  if (kIsWeb) return current();
  final source = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(conversationPermissionSourceProvider);
  final access = ConversationPermissionAccess(source);
  bool valid() => context.mounted && current();
  final lifetime = _PermissionEntryLifetime();
  WidgetsBinding.instance.addObserver(lifetime);
  PermissionGrant? grant;
  try {
    grant = await access.request(
      ConversationPermission.microphone,
      () => valid() && lifetime.current,
    );
    await lifetime.waitForForeground();
  } finally {
    WidgetsBinding.instance.removeObserver(lifetime);
  }
  if (!context.mounted || !valid() || !lifetime.current || grant == null) {
    return false;
  }
  if (grant == PermissionGrant.granted) return true;
  if (grant != PermissionGrant.blocked) {
    showNativeNotice(context, '进入任务需要麦克风权限，请允许后重试。');
    return false;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => NativeBusinessDialog(
      title: '麦克风权限未开启',
      message: '请在系统设置中允许麦克风权限，再进入任务。',
      confirmLabel: '去设置',
      onConfirm: () => Navigator.pop(dialog, true),
      onDismiss: () => Navigator.pop(dialog, false),
    ),
  );
  if (confirmed != true || !valid()) return false;
  return await _readSettings(
        access,
        ConversationPermission.microphone,
        valid,
      ) ==
      PermissionGrant.granted;
}

Future<PermissionGrant?> _readSettings(
  ConversationPermissionAccess access,
  ConversationPermission permission,
  bool Function() current,
) async {
  _PermissionEntryLifetime? lifetime;
  try {
    final grant = await access.settings(
      permission,
      () => current() && (lifetime?.current ?? true),
      onReturned: () {
        lifetime = _PermissionEntryLifetime();
        WidgetsBinding.instance.addObserver(lifetime!);
      },
    );
    await lifetime?.waitForForeground();
    return current() && lifetime?.current != false ? grant : null;
  } finally {
    if (lifetime != null) WidgetsBinding.instance.removeObserver(lifetime!);
  }
}

/// System permission focus loss is transient; a real background abandons entry.
class _PermissionEntryLifetime extends WidgetsBindingObserver {
  _PermissionEntryLifetime() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) didChangeAppLifecycleState(state);
  }
  bool current = true;
  Completer<void>? _resumed;
  Future<void> waitForForeground() async => _resumed?.future;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _resumed ??= Completer<void>();
    } else if (state == AppLifecycleState.resumed) {
      _resumed?.complete();
      _resumed = null;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      current = false;
      _resumed?.complete();
      _resumed = null;
    }
  }
}

/// Called only by an explicit settings action from the current task.
Future<bool> openTaskLocationSettings(
  BuildContext context,
  bool Function() current,
) async {
  final source = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(conversationPermissionSourceProvider);
  final grant = await _readSettings(
    ConversationPermissionAccess(source),
    ConversationPermission.location,
    () => context.mounted && current(),
  );
  if (!context.mounted || !current() || grant == null) return false;
  if (grant == PermissionGrant.granted) return true;
  showNativeNotice(context, '定位权限仍未开启，可在设置中授权或告诉我具体区域。');
  return false;
}
