import 'dart:math';
import 'app_call_record_repository.dart';
import 'dial_recent_call.dart';

class AppDialHistoryRecorder {
  AppDialHistoryRecorder(
    this.repository, {
    DateTime Function()? now,
    String Function()? nextId,
  }) : now = now ?? DateTime.now,
       nextId = nextId ?? _newId;
  final AppCallRecordRepository repository;
  final DateTime Function() now;
  final String Function() nextId;
  static String _newId() {
    final random = Random.secure();
    // Dart's JavaScript target truncates this bit shift; keep the 2^32 bound
    // numeric so browser handoffs can use the same record format as devices.
    return 'system-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(4294967296)}';
  }

  /// Only metadata of a successful platform handoff, never proof of connection.
  Future<void> systemHandoff(String phone, String name, String countryIso) =>
      repository.append(
        DialRecentCall(
          id: nextId(),
          phone: phone,
          name: name,
          startedAtMillis: now().millisecondsSinceEpoch,
          source: DialRecentSource.app,
          kind: DialRecentKind.normal,
          countryIso: countryIso,
        ),
      );
}
