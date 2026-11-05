import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/app_update.dart';
import '../domain/update_install.dart';
import '../domain/startup_update.dart';

class DeviceUpdateInstallPort
    implements UpdateInstallPort, StartupUpdateRecovery {
  const DeviceUpdateInstallPort({
    required this.scope,
    this.channel = const MethodChannel('phone_agent/update_install'),
    this.platform,
    this.web,
  });
  final String scope;
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  Future<Object?> _call(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) {
    if ((web ?? kIsWeb) ||
        (platform ?? defaultTargetPlatform) != TargetPlatform.android) {
      throw UnsupportedError('Android updates only');
    }
    return channel.invokeMethod<Object?>(method, {
      'scope': scope,
      ...arguments,
    });
  }

  Map<String, Object?> _release(
    AppUpdateRelease release, {
    bool download = false,
  }) => {
    'packageName': release.packageName,
    'versionName': release.versionName,
    'versionCode': release.versionCode,
    'fileSize': release.fileSize,
    'checksumSha256': release.checksumSha256.toLowerCase(),
    if (download) 'forceUpdate': release.forceUpdate,
    if (download) 'releaseNotes': release.releaseNotes,
    if (download) 'apkUrl': release.apkUrl,
    if (download) 'downloadHeaders': release.downloadHeaders,
  };
  @override
  Future<AppUpdateRelease?> peek(InstalledApp app) async {
    final value = await _call('peek');
    if (value == null) return null;
    if (value is! Map ||
        value['packageName'] != app.packageName ||
        value['versionName'] is! String ||
        (value['versionName'] as String).trim().isEmpty ||
        value['forceUpdate'] is! bool ||
        value['releaseNotes'] is! String ||
        (value['versionCode'] != null &&
            (value['versionCode'] is! int || value['versionCode'] <= 0)) ||
        (value['fileSize'] != null &&
            (value['fileSize'] is! int || value['fileSize'] <= 0)) ||
        value['checksumSha256'] is! String ||
        ((value['checksumSha256'] as String).isNotEmpty &&
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value['checksumSha256']))) {
      throw const FormatException('Invalid recovered update');
    }
    return AppUpdateRelease(
      hasUpdate: true,
      packageName: app.packageName,
      versionName: value['versionName'],
      versionCode: value['versionCode'],
      forceUpdate: value['forceUpdate'],
      releaseNotes: value['releaseNotes'],
      fileSize: value['fileSize'],
      checksumSha256: value['checksumSha256'],
    );
  }

  @override
  Future<UpdateDownload?> restore(AppUpdateRelease release) async {
    final value = await _call('restore', _release(release));
    return value == null ? null : _snapshot(value);
  }

  @override
  Future<UpdateDownload> begin(AppUpdateRelease release) async =>
      _snapshot(await _call('begin', _release(release, download: true)));
  @override
  Future<UpdateDownload> query(String job) async =>
      _snapshot(await _call('query', {'job': job}));
  @override
  Future<bool> canInstall() async {
    final value = await _call('canInstall');
    if (value is! bool) {
      throw const FormatException('Invalid installation permission');
    }
    return value;
  }

  @override
  Future<void> openPermission() async {
    await _call('permission');
  }

  @override
  Future<void> install(String job) async {
    try {
      await _call('install', {'job': job});
    } on PlatformException catch (error) {
      if (error.code == 'OTA_FILE_UNAVAILABLE') {
        throw const UpdateDownloadUnavailable();
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel(String job) async {
    await _call('cancel', {'job': job});
  }

  static UpdateDownload _snapshot(Object? value) {
    if (value is! Map ||
        value['job'] is! String ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        ).hasMatch(value['job']) ||
        value['received'] is! int ||
        value['received'] < 0 ||
        (value['total'] != null && value['total'] is! int)) {
      throw const FormatException('Invalid download snapshot');
    }
    final status = UpdateDownloadStatus.values.where(
      (s) => s.name == value['status'],
    );
    if (status.length != 1) {
      throw const FormatException('Invalid download state');
    }
    return UpdateDownload(
      value['job'],
      status.single,
      value['received'],
      value['total'],
    );
  }
}
