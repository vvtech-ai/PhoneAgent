import '../../domain/contact_authorization.dart';
import '../../domain/contact_records.dart';

enum ContactPermissionDialogKind { consent, settings }

/// Owns one tab-entry attempt, independently of list/detail lifecycles.
class ContactTabEntryCoordinator {
  ContactTabEntryCoordinator({
    required this.port,
    required this.isIOS,
    required this.isActive,
    required this.confirm,
    required this.openSettings,
    required this.enter,
    required this.notice,
  });
  final ContactAuthorizationPort port;
  final bool isIOS;
  final bool Function() isActive;
  final Future<bool> Function(ContactPermissionDialogKind) confirm;
  final Future<void> Function() openSettings;
  final void Function() enter;
  final void Function(String) notice;
  bool _busy = false, _awaitingSettings = false, _disposed = false;
  int _generation = 0;
  bool _resumePending = false;

  bool get awaitingSettings => _awaitingSettings;
  bool get busy => _busy;

  bool _valid(int token) => !_disposed && token == _generation && isActive();

  void cancel() {
    _generation++;
    _awaitingSettings = false;
    _resumePending = false;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  Future<void> select() async {
    if (_busy || _awaitingSettings || _disposed || !isActive()) return;
    _busy = true;
    final token = ++_generation;
    try {
      final permission = await port.check();
      if (!_valid(token)) return;
      if (permission.canRead) {
        enter();
        return;
      }
      if (permission.access == ContactAccess.unsupported) {
        notice('当前平台不支持读取通讯录');
        return;
      }
      if (isIOS && permission.access != ContactAccess.notDetermined) {
        await _settings(token);
        return;
      }
      final accepted = await confirm(ContactPermissionDialogKind.consent);
      if (!_valid(token)) return;
      if (!accepted) {
        notice('需要通讯录权限才能使用此功能');
        return;
      }
      final result = await port.request();
      if (!_valid(token)) return;
      if (result.canRead) {
        enter();
      } else if (!isIOS && result.canRequest) {
        notice('需要通讯录权限才能使用此功能');
      } else {
        await _settings(token);
      }
    } catch (_) {
      if (_valid(token)) notice('无法检查通讯录权限，请重试');
    } finally {
      _busy = false;
      if (_resumePending) {
        _resumePending = false;
        resumed();
      }
    }
  }

  Future<void> _settings(int token) async {
    final accepted = await confirm(ContactPermissionDialogKind.settings);
    if (!_valid(token) || !accepted) return;
    _awaitingSettings = true;
    try {
      await openSettings();
    } catch (_) {
      _awaitingSettings = false;
      if (_valid(token)) notice('请在系统设置中开启通讯录权限');
    }
  }

  Future<void> resumed() async {
    if (!_awaitingSettings || _disposed) return;
    if (_busy) {
      _resumePending = true;
      return;
    }
    _awaitingSettings = false;
    final token = _generation;
    if (!_valid(token)) return;
    _busy = true;
    try {
      final result = await port.check();
      if (!_valid(token)) return;
      if (result.canRead) {
        enter();
      } else {
        notice('请在系统设置中开启通讯录权限');
      }
    } catch (_) {
      if (_valid(token)) notice('无法检查通讯录权限，请重试');
    } finally {
      _busy = false;
    }
  }
}
