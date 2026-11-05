import '../config/app_config.dart';
import 'account_session.dart';

enum ApiService { sdk, agent }

/// Current service ownership; gateway prefixes are part of the signed URL.
class ServiceRoutes {
  const ServiceRoutes(this.config);
  final AppConfig config;
  ApiService serviceOf(Uri uri) => service(logicalPathOf(uri));

  /// Remove only a configured gateway base; keep the wire URL unchanged.
  String logicalPathOf(Uri uri) {
    final bases =
        [config.apiBaseUri, config.sdkApiBaseUri].whereType<Uri>().toList()
          ..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final base in bases) {
      if (base.origin != uri.origin) continue;
      final prefix = '${base.path.replaceFirst(RegExp(r'/+$'), '')}/';
      if (uri.path.startsWith(prefix)) {
        return uri.path.substring(prefix.length);
      }
    }
    throw ApiFailure.invalidResponse;
  }

  static ApiService service(String path) =>
      path.startsWith('api/agent/') ||
          path == 'api/assistant/agent/contact-lookup-result' ||
          path == 'api/assistant/agent/device-contacts-lookup-result' ||
          path.startsWith('api/agent-artifacts/') ||
          path.startsWith('api/assistant/realtime/call/') ||
          path == 'api/assistant/realtime/call-models/latency'
      ? ApiService.agent
      : ApiService.sdk;

  Uri resolve(String path) {
    final artifact = RegExp(
      r'^api/agent-artifacts/([^/]+)/content$',
    ).firstMatch(path);
    final validArtifact =
        artifact != null &&
        RegExp(
          r'^(skill-template:[A-Za-z0-9_-]+:v1|batch-receipt-csv\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$',
        ).hasMatch(artifact.group(1)!);
    if ((!RegExp(r'^api/[A-Za-z0-9_/-]+$').hasMatch(path) && !validArtifact) ||
        path.contains('//') ||
        path.contains('/../')) {
      throw ApiFailure.invalidResponse;
    }
    final base = service(path) == ApiService.agent
        ? config.apiBaseUri
        : config.sdkApiBaseUri ?? config.apiBaseUri;
    if (base == null) throw ApiFailure.unavailable;
    return base
        .replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/')
        .resolve(path);
  }
}
