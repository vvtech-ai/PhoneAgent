import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'app_local_storage.dart';

/// No legacy migration: only this first release's authentication namespace.
class IosInstallation {
  IosInstallation({
    this.storage = credentials,
    this.channel = AppLocalStorage.channel,
  });
  final FlutterSecureStorage storage;
  final MethodChannel channel;
  static final current = IosInstallation();
  static const tokenPrefix = 'phoneagent.auth-token.v1.';
  static const credentials = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  Future<void>? _initializing;

  Future<void> ensure() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  Future<void> _initialize() async {
    final installed = await channel.invokeMethod<bool>('installed');
    if (installed == true) return;
    if (installed != false) throw StateError('Invalid installation state');
    final items = await storage.readAll();
    for (final key
        in items.keys.where((key) => key.startsWith(tokenPrefix)).toList()) {
      await storage.delete(key: key);
    }
    await channel.invokeMethod<void>('markInstalled');
  }
}
