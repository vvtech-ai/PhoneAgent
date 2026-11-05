import '../../../../core/diagnostics/translation_recording_diagnostics.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/recording/domestic_recording_attachment.dart';
import 'pcm_recording_journal.dart';

class ApiDomesticRecordingUploader implements DomesticRecordingUploader {
  const ApiDomesticRecordingUploader(
    this.api, {
    required this.resolveOwnedFile,
    required this.isCurrent,
  });
  final AccountApi api;
  final Future<File> Function(String clientCallId) resolveOwnedFile;
  final bool Function() isCurrent;

  @override
  Future<void> upload({
    required String serverCallId,
    required String clientCallId,
    required DomesticRecordingAttachment recording,
  }) => TranslationRecordingDiagnostics(api.diagnostics).run(
    'recordingUpload',
    () => _upload(
      serverCallId: serverCallId,
      clientCallId: clientCallId,
      recording: recording,
    ),
  );

  Future<void> _upload({
    required String serverCallId,
    required String clientCallId,
    required DomesticRecordingAttachment recording,
  }) async {
    if (!isCurrent()) {
      throw ApiFailure.sessionChanged;
    }
    final validId = RegExp(r'^[A-Za-z0-9_-]{1,160}$');
    if (!validId.hasMatch(serverCallId) || !validId.hasMatch(clientCallId)) {
      throw ApiFailure.invalidResponse;
    }
    final file = await resolveOwnedFile(clientCallId);
    final size = await file.length();
    if (size <= 0 ||
        size > PcmRecordingJournal.maxBytes ||
        (await sha256.bind(file.openRead()).first).toString() !=
            recording.checksumSha256) {
      throw ApiFailure.invalidResponse;
    }
    if (!isCurrent()) {
      throw ApiFailure.sessionChanged;
    }
    final body = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: 'recording.m4a',
        contentType: DioMediaType('audio', 'mp4'),
      ),
      'durationMillis': recording.durationMillis.toString(),
      'checksumSha256': recording.checksumSha256,
    });
    if (!isCurrent()) {
      throw ApiFailure.sessionChanged;
    }
    final result = AccountApi.object(
      await api.request(
        'api/realtime-translation-calls/$serverCallId/recording-content',
        method: 'PUT',
        body: body,
      ),
    );
    if (!isCurrent()) {
      throw ApiFailure.sessionChanged;
    }
    if (result['source'] != 'PHONE_AGENT' ||
        result['contentType'] != 'audio/mp4' ||
        result['sizeBytes'] != size ||
        result['checksumSha256'] != recording.checksumSha256) {
      throw ApiFailure.invalidResponse;
    }
  }
}
