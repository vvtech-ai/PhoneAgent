import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/network/signing/c1_transport.dart';
import '../domain/app_update.dart';
import '../domain/ios_update_link.dart';

class ApiAppUpdateRepository implements AppUpdateRepository {
  ApiAppUpdateRepository(
    this.api, {
    required this.accountId,
    required this.channel,
    this.sourceType = 0,
  });
  final AccountApi api;
  final String accountId, channel;
  final int sourceType;
  @override
  Future<AppUpdateRelease> check(InstalledApp app) async {
    final trace = C1Transport.newDeviceId();
    final watch = Stopwatch()..start();
    void event(DiagnosticResult result, {DiagnosticFailureKind? failure}) =>
        emitDiagnostic(
          api.diagnostics,
          DiagnosticEvent(
            operation: DiagnosticOperation.otaCheck,
            result: result,
            traceId: trace,
            elapsedMs: watch.elapsedMilliseconds,
            failureKind: failure,
          ),
        );
    event(DiagnosticResult.started);
    try {
      final release = await _check(app);
      event(DiagnosticResult.succeeded);
      return release;
    } catch (error) {
      event(
        DiagnosticResult.failed,
        failure: error == ApiFailure.invalidResponse || error is FormatException
            ? DiagnosticFailureKind.format
            : error == ApiFailure.unavailable
            ? DiagnosticFailureKind.platform
            : error == ApiFailure.sessionChanged || error == ApiFailure.rejected
            ? DiagnosticFailureKind.state
            : DiagnosticFailureKind.other,
      );
      rethrow;
    }
  }

  Future<AppUpdateRelease> _check(InstalledApp app) async {
    if (!app.valid || (sourceType != 0 && sourceType != 1)) {
      throw ApiFailure.invalidResponse;
    }
    final data = await api.request(
      'api/ota/check',
      method: 'POST',
      body: {
        'packageName': app.packageName,
        'currentVersionCode': app.versionCode,
        'currentVersionName': app.versionName,
        'sourceType': sourceType,
        if (accountId.isNotEmpty) 'deviceId': accountId,
        if (channel.isNotEmpty) 'channel': channel,
      },
    );
    if (data is! Map ||
        data['hasUpdate'] is! bool ||
        data['packageName'] != app.packageName ||
        data['forceUpdate'] is! bool ||
        (data['sourceType'] != null &&
            (data['sourceType'] is! int || data['sourceType'] != sourceType))) {
      throw ApiFailure.invalidResponse;
    }
    if (data['hasUpdate'] == false) {
      return AppUpdateRelease(
        hasUpdate: false,
        packageName: app.packageName,
        sourceType: sourceType,
      );
    }
    String text(String key) =>
        data[key] is String ? (data[key] as String).trim() : '';
    int? number(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! int || value <= 0) throw ApiFailure.invalidResponse;
      return value;
    }

    final name = text('versionName'), code = number('versionCode');
    if (sourceType == 1) {
      if (name.isEmpty ||
          (data['iosSourceUrl'] != null && data['iosSourceUrl'] is! String)) {
        throw ApiFailure.invalidResponse;
      }
      return AppUpdateRelease(
        hasUpdate: true,
        packageName: app.packageName,
        versionName: name,
        versionCode: code,
        forceUpdate: data['forceUpdate'] as bool,
        releaseNotes: text('releaseNotes'),
        sourceType: 1,
        iosSourceUrl: IosUpdateLink.resolve(text('iosSourceUrl')),
      );
    }
    final url = text('apkUrl'), checksum = text('checksumSha256');
    final uri = Uri.tryParse(url);
    if (name.isEmpty ||
        uri == null ||
        !const {'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (checksum.isNotEmpty &&
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum))) {
      throw ApiFailure.invalidResponse;
    }
    final headers = <String, String>{};
    final rawHeaders = data['downloadHeaders'];
    if (rawHeaders != null) {
      if (rawHeaders is! Map) throw ApiFailure.invalidResponse;
      for (final entry in rawHeaders.entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(entry.key as String) ||
            (entry.value as String).contains(RegExp(r'[\r\n]'))) {
          throw ApiFailure.invalidResponse;
        }
        headers[entry.key as String] = entry.value as String;
      }
    }
    return AppUpdateRelease(
      hasUpdate: true,
      packageName: app.packageName,
      versionName: name,
      versionCode: code,
      forceUpdate: data['forceUpdate'] as bool,
      releaseNotes: text('releaseNotes'),
      fileSize: number('fileSize'),
      apkUrl: url,
      checksumSha256: checksum,
      downloadHeaders: Map.unmodifiable(headers),
    );
  }
}
