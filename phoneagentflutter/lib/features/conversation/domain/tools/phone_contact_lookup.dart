import '../../../contacts/domain/contact_records.dart';
import '../../../contacts/domain/contact_phone_policy.dart';
import '../agent_protocol.dart';
import 'contact_lookup_access_policy.dart';

abstract interface class ContactLookupContinuation {
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  });
}

/// Optional capability used by the live conversation flow to keep a contact
/// callback on the same client-owned continuation command.
abstract interface class CommandAwareContactLookupContinuation {
  Future<AgentEvent> submitWithCommand({
    required String sessionId,
    required String toolCallId,
    required String commandId,
    required Map<String, Object?> result,
  });
}

/// Shared v65 phone lookup. No directory upload, cache, UI or media dependency.
class PhoneContactLookup {
  PhoneContactLookup(this._contacts, this._continuation);
  final DeviceContactSource _contacts;
  final ContactLookupContinuation _continuation;

  Future<AgentEvent?> run({
    required String sessionId,
    required String toolCallId,
    required String phone,
    required bool Function() isCurrent,
    String continuationCommandId = '',
    void Function()? onLimitedAccess,
  }) async {
    if (!isCurrent()) return null;
    if (sessionId.trim().isEmpty ||
        toolCallId.trim().isEmpty ||
        phone.trim().isEmpty) {
      throw const FormatException('Missing contact lookup context');
    }
    Map<String, Object?> result;
    try {
      final snapshot = await _contacts.load(requestPermission: true);
      result = snapshot.canRead
          ? ContactLookupAccessPolicy.phone(
              match(phone, snapshot.rows),
              snapshot.access == ContactAccess.limited,
            )
          : {
              'found': false,
              'reason': snapshot.access == ContactAccess.unsupported
                  ? 'DEVICE_LOOKUP_FAILED'
                  : 'PERMISSION_DENIED',
            };
    } catch (_) {
      result = {'found': false, 'reason': 'DEVICE_LOOKUP_FAILED'};
    }
    if (!isCurrent()) return null;
    if (result['reason'] == 'PERMISSION_LIMITED') {
      onLimitedAccess?.call();
      if (!isCurrent()) return null;
    }
    final response =
        continuationCommandId.trim().isNotEmpty &&
            _continuation is CommandAwareContactLookupContinuation
        ? await (_continuation as CommandAwareContactLookupContinuation)
              .submitWithCommand(
                sessionId: sessionId,
                toolCallId: toolCallId,
                commandId: continuationCommandId,
                result: result,
              )
        : await _continuation.submit(
            sessionId: sessionId,
            toolCallId: toolCallId,
            result: result,
          );
    return isCurrent() ? response : null;
  }

  static Map<String, Object?> match(String phone, List<DeviceContactRow> rows) {
    final target = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (target.isEmpty) return {'found': false};
    for (final row in rows) {
      final number = ContactPhonePolicy.resolve(
        row.phone,
        normalized: row.normalizedPhone,
      )?.lookup.replaceAll(RegExp(r'[^0-9]'), '');
      if (number == null || number.isEmpty) continue;
      if (!number.endsWith(target) && !target.endsWith(number)) continue;
      final name = row.name.trim(), note = row.label.trim();
      // Do not substitute the contacts list's display-only unknown-name label.
      if (name.isEmpty) return {'found': false};
      return {
        'found': true,
        'source': 'device',
        'displayName': name,
        if (note.isNotEmpty) 'note': note,
      };
    }
    return {'found': false};
  }
}
