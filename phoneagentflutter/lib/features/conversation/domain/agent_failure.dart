import 'agent_protocol.dart';

/// v65 Err wire contract. Classification never grants permission to retry a POST.
class AgentFailure implements Exception {
  const AgentFailure({
    this.message = '',
    this.errorCode = '',
    this.category = '',
    this.retryable,
    this.recoveryAction = '',
    this.traceId = '',
    this.stage = '',
  });
  final String message, errorCode, category, recoveryAction, traceId, stage;
  final bool? retryable;

  factory AgentFailure.fromEvent(AgentEvent event) {
    String text(String key) => event.payload[key] is String
        ? (event.payload[key] as String).trim()
        : '';
    final retry = event.payload['retryable'];
    return AgentFailure(
      message: event.text,
      errorCode: text('errorCode'),
      category: text('category'),
      retryable: retry is bool ? retry : null,
      recoveryAction: text('recoveryAction'),
      traceId: text('traceId'),
      stage: text('stage'),
    );
  }

  bool get hasStructuredFailure => errorCode.isNotEmpty || category.isNotEmpty;
  bool get isNetworkFailure => hasStructuredFailure
      ? category.toUpperCase() == 'NETWORK' ||
            errorCode.toUpperCase() == 'NETWORK_TRANSPORT'
      : _transportPatterns.any((pattern) => pattern.hasMatch(message));

  // Deliberately excludes generic model timeouts, HTTP 429/5xx and provider
  // availability. These are not evidence of device transport interruption.
  static final _transportPatterns = [
    r'\bhttp\s*408\b',
    r'failed\s+to\s+connect',
    r'(?:first_audio_timeout|completion_timeout|voice\s+tts\s+failed|tts.*timeout|asr.*timeout)',
    r'(?:connect|read|write)\s+timed?\s*out',
    r'connection\s+timed?\s*out',
    r'network\s+(?:connection\s+)?(?:error|timeout|failure|unavailable)',
    r'unable\s+to\s+resolve\s+host',
    r'unknownhost|sockettimeout|connectexception',
    r'connection\s+refused|connection\s+reset|connection\s+closed|broken\s+pipe',
    r'no\s+route\s+to\s+host|network\s+is\s+unreachable',
    r'econnrefused|econnreset|enetunreach|ehostunreach|socketexception',
    r'sslhandshake|clearttext|cleartext',
    r'网络异常|网络连接异常|网络错误|连接异常|连接中断|无法连接|连接失败|域名解析失败|主机无法解析',
  ].map((pattern) => RegExp(pattern, caseSensitive: false)).toList();

  @override
  String toString() => 'AgentFailure(redacted)';
}
