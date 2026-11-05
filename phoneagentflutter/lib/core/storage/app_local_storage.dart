import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps existing Android/plugin options; iOS values live in protected sandbox
/// files. Only the encrypted-file key is stored in Keychain by the native port.
class AppLocalStorage extends FlutterSecureStorage {
  const AppLocalStorage({
    super.iOptions,
    super.aOptions,
    this.preference = false,
  });
  final bool preference;
  static const channel = MethodChannel('phone_agent/local_storage');
  static bool get usesSandbox =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Map<String, Object> _arguments(String key) => {
    'key': key,
    'kind': preference ? 'preference' : 'encrypted',
  };
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => usesSandbox
      ? channel.invokeMethod<String>('read', _arguments(key))
      : super.read(
          key: key,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => usesSandbox
      ? value == null
            ? delete(key: key)
            : channel.invokeMethod<void>('write', {
                ..._arguments(key),
                'value': value,
              })
      : super.write(
          key: key,
          value: value,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => usesSandbox
      ? channel.invokeMethod<void>('delete', _arguments(key))
      : super.delete(
          key: key,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => usesSandbox
      ? read(key: key).then((value) => value != null)
      : super.containsKey(
          key: key,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (usesSandbox) throw UnsupportedError('Use account-scoped reads');
    return super.readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (usesSandbox) throw UnsupportedError('Use account-scoped deletion');
    return super.deleteAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
