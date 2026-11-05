import '../../../contacts/domain/contact_records.dart';
import '../../../contacts/domain/contact_name_matcher.dart';
import '../../../contacts/domain/contact_pinyin_search.dart';
import '../agent_protocol.dart';
import 'contact_lookup_access_policy.dart';

abstract interface class NameContactLookupContinuation {
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  });
}

abstract interface class CommandAwareNameContactLookupContinuation {
  Future<AgentEvent> submitNamesWithCommand({
    required String sessionId,
    required String toolCallId,
    required String commandId,
    required List<Map<String, Object?>> results,
  });
}

class NameContactLookup {
  NameContactLookup(this._contacts, this._continuation, this._dictionary);
  final DeviceContactSource _contacts;
  final NameContactLookupContinuation _continuation;
  final ContactNameDictionary _dictionary;

  Future<AgentEvent?> run({
    required String sessionId,
    required String toolCallId,
    required List<String> names,
    required ContactInputSource source,
    required bool Function() isCurrent,
    String continuationCommandId = '',
    void Function()? onLimitedAccess,
  }) async {
    if (!isCurrent()) return null;
    final requested = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    if (sessionId.trim().isEmpty ||
        toolCallId.trim().isEmpty ||
        requested.isEmpty) {
      throw const FormatException('Missing name lookup context');
    }
    List<Map<String, Object?>> unavailable(String status) => requested
        .map(
          (name) => <String, Object?>{
            'name': name,
            'status': status,
            'inputSource': source.name,
          },
        )
        .toList();
    List<Map<String, Object?>> results;
    try {
      final snapshot = await _contacts.load(requestPermission: true);
      results = snapshot.canRead
          ? ContactLookupAccessPolicy.names(
              ContactNameMatcher(
                snapshot.rows,
                _dictionary,
              ).resolve(requested, source),
              snapshot.access == ContactAccess.limited,
            )
          : unavailable(
              snapshot.access == ContactAccess.unsupported
                  ? 'UNAVAILABLE'
                  : 'PERMISSION_DENIED',
            );
    } catch (_) {
      results = unavailable('UNAVAILABLE');
    }
    if (!isCurrent()) return null;
    if (results.any((r) => r['status'] == 'PERMISSION_LIMITED')) {
      onLimitedAccess?.call();
      if (!isCurrent()) return null;
    }
    final response =
        continuationCommandId.trim().isNotEmpty &&
            _continuation is CommandAwareNameContactLookupContinuation
        ? await (_continuation as CommandAwareNameContactLookupContinuation)
              .submitNamesWithCommand(
                sessionId: sessionId,
                toolCallId: toolCallId,
                commandId: continuationCommandId,
                results: results,
              )
        : await _continuation.submitNames(
            sessionId: sessionId,
            toolCallId: toolCallId,
            results: results,
          );
    return isCurrent() ? response : null;
  }
}
