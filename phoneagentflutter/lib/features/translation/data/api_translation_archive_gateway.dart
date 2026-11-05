import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../domain/translation_archive.dart';
import '../domain/recording/domestic_recording_attachment.dart';
import 'translation_archive_codec.dart';

class ApiTranslationArchiveGateway implements TranslationArchivePhasedGateway {
  const ApiTranslationArchiveGateway(
    this.api,
    this.accountId, {
    this.recordingUploader,
    this.onDomesticArchived,
  });
  final DomesticRecordingUploader? recordingUploader;
  final Future<void> Function(String serverCallId, String clientCallId)?
  onDomesticArchived;
  final AccountApi api;
  final String accountId;
  @override
  Future<String> archive(TranslationArchiveEntry entry) async {
    final id = await createRecord(entry);
    if (entry.route == TranslationArchiveRoute.domesticSip) {
      await uploadRecording(entry, id);
    }
    return id;
  }

  @override
  Future<String> createRecord(TranslationArchiveEntry entry) async {
    final locator = entry.locator,
        connected = entry.connectedAt,
        ended = entry.endedAt;
    final domestic = entry.route == TranslationArchiveRoute.domesticSip;
    if (entry.recordingPending ||
        entry.accountId != accountId ||
        entry.stage != TranslationArchiveStage.ready ||
        !RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(entry.clientCallId) ||
        (domestic
            ? locator != null
            : (locator == null ||
                  !const {'US', 'JP'}.contains(locator.cluster) ||
                  locator.sessionId.trim().isEmpty ||
                  locator.grant.trim().isEmpty)) ||
        (entry.recording != null &&
            (!domestic ||
                connected == null ||
                ended == null ||
                entry.recording!.durationMillis != ended - connected)) ||
        connected == null ||
        ended == null ||
        ended <= connected) {
      throw ApiFailure.invalidResponse;
    }
    final result = AccountApi.object(
      await api.request(
        'api/realtime-translation-calls/${entry.clientCallId}',
        method: 'PUT',
        body: {
          'route': domestic ? 'DOMESTIC_ANDROID' : 'WORLD_CALL',
          'targetName': entry.targetName,
          'phoneNumber': entry.phone,
          'myLanguage': entry.myLanguage,
          'peerLanguage': entry.peerLanguage,
          'connectedAt': DateTime.fromMillisecondsSinceEpoch(
            connected,
            isUtc: true,
          ).toIso8601String(),
          'endedAt': DateTime.fromMillisecondsSinceEpoch(
            ended,
            isUtc: true,
          ).toIso8601String(),
          'transcripts': entry.transcripts
              .map(TranslationArchiveCodec.transcript)
              .toList(),
          if (!domestic && locator != null) ...{
            'externalClusterId': locator.cluster,
            'externalCallSessionId': locator.sessionId,
            'recordingAccessGrant': locator.grant,
          },
        },
      ),
    );
    final id = result['callId'];
    if (id is! String || id.trim().isEmpty || result['created'] is! bool) {
      throw ApiFailure.invalidResponse;
    }
    return id;
  }

  @override
  Future<void> uploadRecording(
    TranslationArchiveEntry entry,
    String serverCallId,
  ) async {
    if (entry.accountId != accountId ||
        entry.route != TranslationArchiveRoute.domesticSip ||
        entry.recordingPending ||
        (entry.recording != null &&
            (recordingUploader == null ||
                entry.connectedAt == null ||
                entry.endedAt == null ||
                entry.recording!.durationMillis !=
                    entry.endedAt! - entry.connectedAt!)) ||
        serverCallId.trim().isEmpty ||
        (entry.serverCallId != null && entry.serverCallId != serverCallId)) {
      throw ApiFailure.invalidResponse;
    }
    await onDomesticArchived?.call(serverCallId, entry.clientCallId);
    if (entry.recording case final recording?) {
      // The archive controller retains its journal until both requests complete.
      await recordingUploader!.upload(
        serverCallId: serverCallId,
        clientCallId: entry.clientCallId,
        recording: recording,
      );
    }
  }
}
