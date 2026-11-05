import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart'
    show PlatformException, MissingPluginException;
import '../../../../core/diagnostics/device_environment.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../domain/app_log_report.dart';

class ZipLogRepository implements AppLogRepository {
  ZipLogRepository(
    this.journal, {
    required this.uploadBundle,
    this.maxPlainBytes = 4 * 1024 * 1024,
    this.beforePrepare,
    this.readEnvironment,
  });
  final DiagnosticJournal journal;
  final int maxPlainBytes;
  final Future<void> Function(AppLogBundle bundle) uploadBundle;
  final Future<void> Function()? beforePrepare;
  final Future<DeviceEnvironment> Function()? readEnvironment;
  @override
  Future<AppLogBundle> prepare() async {
    await beforePrepare?.call();
    DeviceEnvironment? environment;
    if (readEnvironment != null) {
      try {
        environment = await readEnvironment!();
      } on PlatformException {
        /* Keep the log snapshot available for retry. */
      } on MissingPluginException {
        /* Native metadata may be unavailable. */
      } on FormatException {
        /* Do not invent device fields. */
      } on UnsupportedError {
        /* Non-mobile preview has no device metadata. */
      }
    }
    final snapshot = await journal.snapshot(maxBytes: maxPlainBytes);
    final data = utf8.encode(
      snapshot.events.map((e) => jsonEncode(e.toJson())).join('\n'),
    );
    final archive = Archive()
      ..addFile(ArchiveFile('diagnostics.jsonl', data.length, data));
    if (readEnvironment != null) {
      final metadata = utf8.encode(
        jsonEncode(environment?.toJson() ?? {'schema': 1, 'available': false}),
      );
      archive.addFile(
        ArchiveFile('device-environment.json', metadata.length, metadata),
      );
    }
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) throw StateError('Compression failed');
    if (zipped.length > 5 * 1024 * 1024) {
      throw StateError('Diagnostic ZIP too large');
    }
    return AppLogBundle(
      watermark: snapshot.watermark,
      count: snapshot.events.length,
      hasMore: snapshot.hasMore,
      bytes: Uint8List.fromList(zipped),
      fileName:
          'phoneagent-diagnostics-${DateTime.now().toUtc().millisecondsSinceEpoch}.zip',
      environment: environment,
    );
  }

  @override
  Future<void> upload(AppLogBundle bundle) => uploadBundle(bundle);
  @override
  Future<void> acknowledge(AppLogBundle bundle) =>
      journal.acknowledge(bundle.watermark);
}

class ApiLogUploader {
  ApiLogUploader(this.api, this.accountId, this.deviceInfo);
  final AccountApi api;
  final String accountId, deviceInfo;
  Future<void> upload(AppLogBundle bundle) async {
    if (bundle.bytes.isEmpty ||
        bundle.bytes.length > 5 * 1024 * 1024 ||
        !RegExp(
          r'^phoneagent-diagnostics-\d+\.zip$',
        ).hasMatch(bundle.fileName)) {
      throw ApiFailure.invalidResponse;
    }
    final result = AccountApi.object(
      await api.request(
        'api/logs/upload',
        method: 'POST',
        body: FormData.fromMap({
          'accountId': accountId,
          'deviceInfo': deviceInfo,
          'file': MultipartFile.fromBytes(
            bundle.bytes,
            filename: bundle.fileName,
            contentType: DioMediaType('application', 'zip'),
          ),
        }),
      ),
    );
    if (result['originalFileName'] != bundle.fileName ||
        result['id'] is! int ||
        (result['id'] as int) <= 0 ||
        result['accountId'] != accountId ||
        result['fileSize'] != bundle.bytes.length ||
        result['checksumSha256'] != sha256.convert(bundle.bytes).toString()) {
      throw ApiFailure.invalidResponse;
    }
  }
}
