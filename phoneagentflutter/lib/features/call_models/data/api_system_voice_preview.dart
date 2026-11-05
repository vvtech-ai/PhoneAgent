import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../../voice_clone/domain/clone_preview_player.dart';
import '../domain/system_voice_preview.dart';
import 'api_call_model_repository.dart';

/// Signed media URLs use an isolated client, never account bearer/sign headers.
class ApiSystemVoicePreview implements SystemVoicePreviewPort {
  ApiSystemVoicePreview(
    this.api,
    this.modelId,
    this.player, {
    this.loadClone,
    this.resolveVoice,
    Dio? client,
  }) : _client = client ?? Dio() {
    _client.options.connectTimeout = const Duration(seconds: 8);
  }
  final AccountApi api;
  final String modelId;
  final ClonePreviewPlayer player;
  final Future<Uint8List> Function(bool current)? loadClone;
  final Future<({String modelId, String previewAudioUrl})> Function(
    String voiceId,
  )?
  resolveVoice;
  final Dio _client;
  bool _closed = false;
  @override
  Future<Uint8List> load(String voiceId) async {
    if (_closed) throw StateError('Preview closed');
    if (voiceId == cloneCurrentPreviewId ||
        voiceId == cloneCandidatePreviewId) {
      final loader = loadClone;
      if (loader == null) throw ApiFailure.invalidResponse;
      return loader(voiceId == cloneCurrentPreviewId);
    }
    var selectedModelId = modelId;
    String address;
    if (resolveVoice != null) {
      final selected = await resolveVoice!(voiceId);
      selectedModelId = selected.modelId;
      address = selected.previewAudioUrl;
    } else {
      final catalog = ApiCallModelRepository.voices(
        await api.request(
          'api/account/settings/realtime-call-voice/models/${Uri.encodeComponent(modelId)}',
        ),
      );
      final voice = catalog.voices.where((v) => v.id == voiceId).firstOrNull;
      if (voice == null) throw ApiFailure.invalidResponse;
      address = voice.previewAudioUrl;
    }
    if (selectedModelId.trim().isEmpty) throw ApiFailure.invalidResponse;
    if (address.isEmpty) {
      final data = AccountApi.object(
        await api.request(
          'api/account/settings/system-voice-preview/models/${Uri.encodeComponent(selectedModelId)}/voices/${Uri.encodeComponent(voiceId)}',
          method: 'POST',
        ),
      );
      address = data['url'] is String ? data['url'] as String : '';
    }
    final uri = Uri.tryParse(address);
    if (_closed ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ApiFailure.invalidResponse;
    }
    final response = await _client.getUri<ResponseBody>(
      uri,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null || response.statusCode != 200) {
      await body?.stream.listen((_) {}).cancel();
      throw ApiFailure.invalidResponse;
    }
    const limit = 10 * 1024 * 1024;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      if (_closed || bytes.length + chunk.length > limit) {
        throw ApiFailure.invalidResponse;
      }
      bytes.add(chunk);
    }
    if (bytes.isEmpty) throw ApiFailure.invalidResponse;
    return bytes.takeBytes();
  }

  @override
  Future<void> play(Uint8List bytes) => player.play(bytes);
  @override
  Future<void> stop() => player.stop();
  @override
  Future<void> close() async {
    _closed = true;
    _client.close(force: true);
    await player.close();
  }
}
