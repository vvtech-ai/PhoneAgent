import 'dart:typed_data';
import '../../../core/network/account_api.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/network/account_session.dart';
import '../../call_models/domain/call_models.dart';
import '../domain/clone_candidate.dart';
import '../domain/clone_completion.dart';
import 'clone_candidate_mapper.dart';

class ApiCloneCompletionPort implements CloneCompletionPort {
  const ApiCloneCompletionPort(this.api);
  final AccountApi api;
  static const _root = 'api/account/settings/voice-clone/models';

  @override
  Future<CloneCandidate> confirm(CloneCandidate candidate) async {
    final model = _validate(candidate);
    final result = CloneCandidateMapper.candidate(
      await api.request(
        '$_root/$model/candidate/confirm',
        method: 'POST',
        query: const {'activate': true},
      ),
      model,
      onInvalid: (details) => emitDiagnostic(
        api.diagnostics,
        DiagnosticEvent(
          operation: DiagnosticOperation.voiceCloneCandidateDecode,
          result: DiagnosticResult.failed,
          failureKind: DiagnosticFailureKind.format,
          clone: details,
        ),
      ),
    );
    if (result.id.isNotEmpty &&
        candidate.id.isNotEmpty &&
        result.id != candidate.id) {
      throw ApiFailure.invalidResponse;
    }
    return result;
  }

  @override
  Future<bool> isActivated(CloneCandidate candidate) async {
    final model = _validate(candidate);
    if (candidate.providerAssetId.isEmpty) return false;
    final root = AccountApi.object(await api.request(_root));
    final list = root['models'];
    if (list is! List) throw ApiFailure.invalidResponse;
    final matches = list
        .map(AccountApi.object)
        .where((value) => normalizeProvider(_text(value, 'modelId')) == model);
    if (matches.length != 1) throw ApiFailure.invalidResponse;
    final item = matches.single;
    final current = AccountApi.object(item['current']);
    final returnedModel = _text(current, 'modelId');
    if (returnedModel.isNotEmpty && normalizeProvider(returnedModel) != model) {
      throw ApiFailure.invalidResponse;
    }
    return item['candidate'] == null &&
        _active(current['active']) &&
        _text(current, 'status').toUpperCase() == 'READY' &&
        _text(current, 'providerAssetId') == candidate.providerAssetId;
  }

  @override
  Future<Uint8List> preview(String modelId, {bool current = false}) async {
    final model = CloneCandidateMapper.model(modelId);
    final kind = current ? 'clone' : 'candidate';
    for (var attempt = 0; ; attempt++) {
      try {
        return await api.download(
          '$_root/$model/$kind/preview',
          maxBytes: 10 * 1024 * 1024,
          mediaTypes: const {'audio/wav', 'audio/x-wav'},
        );
      } on ApiFailure catch (error) {
        // Native retries the read while the generated preview becomes available.
        // Account ownership and malformed media are never retried.
        if (attempt == 2 ||
            (error != ApiFailure.network && error != ApiFailure.rejected)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  @override
  Future<void> restoreSystemVoice(String modelId) async {
    final model = CloneCandidateMapper.model(modelId);
    final path = 'api/account/settings/realtime-call-voice/models/$model';
    final result = AccountApi.object(
      await api.request(
        path,
        method: 'PUT',
        body: {'voice': null, 'selectionMode': 'AI'},
      ),
    );
    if (_restored(result)) return;
    if (!_restored(AccountApi.object(await api.request(path)))) {
      throw ApiFailure.invalidResponse;
    }
  }

  static bool _restored(Map<String, dynamic> value) {
    final voice = _text(value, 'activeVoice').trim().toLowerCase();
    final voices = value['voices'];
    if (voice.isEmpty ||
        voices is! List ||
        _text(value, 'selectionMode').toUpperCase() != 'AI') {
      return false;
    }
    final seen = <String>{};
    final selected = voices
        .map(AccountApi.object)
        .where((entry) => seen.add(_text(entry, 'voice').toLowerCase()))
        .where((entry) => entry['selected'] == true)
        .toList();
    return selected.length == 1 &&
        _text(selected.single, 'voice').toLowerCase() == voice;
  }

  static String _validate(CloneCandidate candidate) {
    if (!candidate.ready) {
      throw ApiFailure.invalidResponse;
    }
    return CloneCandidateMapper.model(candidate.modelId);
  }

  static bool _active(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    throw ApiFailure.invalidResponse;
  }

  static String _text(Map<String, dynamic> value, String key) {
    final field = value[key];
    if (field == null) return '';
    if (field is String || field is num || field is bool) {
      return field.toString().trim();
    }
    throw ApiFailure.invalidResponse;
  }
}
