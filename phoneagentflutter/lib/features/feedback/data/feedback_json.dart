import '../../../core/network/account_session.dart';

/// Narrow wire accessors: malformed payloads fail without exposing the body.
class FeedbackJson {
  const FeedbackJson(this.value);
  final Map<String, Object?> value;
  String text(String key) {
    final item = value[key];
    if (item != null && item is! String) throw ApiFailure.invalidResponse;
    return (item as String? ?? '').trim();
  }

  int? integer(String key) {
    final item = value[key];
    if (item != null && item is! int) throw ApiFailure.invalidResponse;
    return item as int?;
  }

  bool flag(String key) {
    final item = value[key];
    if (item != null && item is! bool) throw ApiFailure.invalidResponse;
    return item == true;
  }

  static String safeId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw ApiFailure.invalidResponse;
    }
    return id;
  }
}
