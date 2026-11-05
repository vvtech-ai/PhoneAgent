import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../../translation_history/domain/recording_audio.dart';
import '../domain/call_recording.dart';

/// Bound to one account API and call. Never caches or logs a playback grant.
class ApiCallRecordingRepository implements CallRecordingRepository {
  ApiCallRecordingRepository({
    required this.api,
    required this.apiBase,
    required this.callId,
    required this.isCurrent,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AccountApi api;
  final Uri apiBase;
  final String callId;
  final bool Function() isCurrent;
  final DateTime Function() _now;
  bool _closed = false;

  void _check() {
    if (_closed || !isCurrent()) throw ApiFailure.sessionChanged;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(callId)) {
      throw ApiFailure.invalidResponse;
    }
  }

  @override
  Future<CallRecordingInfo> metadata() async {
    _check();
    final raw = await api.request('api/agent-calls/$callId/recording');
    _check();
    if (raw is! Map ||
        raw['callId'] != callId ||
        raw['status'] is! String ||
        (raw['status'] as String).trim().isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    return CallRecordingInfo(
      callId: callId,
      status: (raw['status'] as String).trim(),
      durationMillis: _nonNegative(raw['durationMillis']),
      sizeBytes: _nonNegative(raw['sizeBytes']),
    );
  }

  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async {
    _check();
    // Each explicit start/retry gets a fresh source. Metadata is not a gate.
    final raw = await api.request(
      'api/agent-calls/$callId/recording/play-token',
      method: 'POST',
    );
    _check();
    if (raw is! Map || raw['url'] is! String) {
      throw ApiFailure.invalidResponse;
    }
    final uri = _contentUri((raw['url'] as String).trim());
    final contentType = raw['contentType'] ?? 'audio/wav';
    if (contentType is! String ||
        !RegExp(r'^audio/[A-Za-z0-9.+-]+$').hasMatch(contentType)) {
      throw ApiFailure.invalidResponse;
    }
    final size = _nonNegative(raw['sizeBytes']);
    if (size == 0) throw ApiFailure.invalidResponse;
    final expires = raw['expiresAt'];
    if (expires != null) {
      final parsed = expires is String ? DateTime.tryParse(expires) : null;
      if (parsed == null || !parsed.isAfter(_now())) {
        throw ApiFailure.invalidResponse;
      }
    }
    return RecordingAudioAsset.remote(
      uri,
      'recording.wav',
      contentType,
      size: size,
    );
  }

  Uri _contentUri(String raw) {
    if (!{'https', 'http'}.contains(apiBase.scheme) ||
        apiBase.host.isEmpty ||
        apiBase.userInfo.isNotEmpty ||
        apiBase.hasQuery ||
        apiBase.hasFragment) {
      throw ApiFailure.invalidResponse;
    }
    final base = '${apiBase.toString().replaceFirst(RegExp(r'/+$'), '')}/';
    const path = 'api/agent-calls/recording-content/';
    final relative = raw.startsWith('/') ? raw.substring(1) : raw;
    final pattern = RegExp('^${RegExp.escape(path)}[a-f0-9]{32}\$');
    if (pattern.hasMatch(relative)) return Uri.parse('$base$relative');
    final prefix = '$base$path';
    if (raw.startsWith(prefix) &&
        RegExp(r'^[a-f0-9]{32}$').hasMatch(raw.substring(prefix.length))) {
      return Uri.parse(raw);
    }
    // No foreign host, userinfo, query, fragment, traversal or encoded path.
    throw ApiFailure.invalidResponse;
  }

  int? _nonNegative(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 0) throw ApiFailure.invalidResponse;
    return value;
  }

  @override
  void close() => _closed = true; // The shared AccountApi belongs to its provider.
}
