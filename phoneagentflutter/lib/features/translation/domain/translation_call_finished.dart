import 'dart:math';
import '../../dialer/domain/dial_recent_call.dart';

class TranslationCallContext {
  const TranslationCallContext({
    required this.clientCallId,
    this.targetName = '',
    this.countryIso = '',
    this.allowUnverifiedNumber = false,
  });
  factory TranslationCallContext.create({
    String targetName = '',
    String countryIso = '',
    bool allowUnverifiedNumber = false,
  }) {
    final random = Random.secure();
    return TranslationCallContext(
      clientCallId:
          'translation-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
      allowUnverifiedNumber: allowUnverifiedNumber,
      targetName: targetName.trim(),
      countryIso: countryIso.trim(),
    );
  }
  final String clientCallId, targetName, countryIso;
  final bool allowUnverifiedNumber;
}

/// Local finished metadata only: no grant, transcript, charge or remote success.
class TranslationCallFinished {
  const TranslationCallFinished({
    required this.context,
    required this.accountId,
    required this.phone,
    required this.callerLanguage,
    required this.peerLanguage,
    required this.startedAtMillis,
    required this.endedAtMillis,
    required this.connectedAtMillis,
    required this.failed,
  });
  final TranslationCallContext context;
  final String accountId, phone, callerLanguage, peerLanguage;
  final int startedAtMillis, endedAtMillis;
  final int? connectedAtMillis;
  final bool failed;

  DialRecentCall get record => DialRecentCall(
    id: context.clientCallId,
    phone: phone,
    name: context.targetName.trim(),
    countryIso: context.countryIso,
    callerLanguage: callerLanguage,
    peerLanguage: peerLanguage,
    startedAtMillis: startedAtMillis,
    source: DialRecentSource.app,
    kind: DialRecentKind.translation,
  );
}
