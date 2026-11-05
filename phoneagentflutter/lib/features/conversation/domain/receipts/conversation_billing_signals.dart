import 'dart:convert';
import '../../../points/domain/wallet_settlement_sync.dart';
import '../conversation_messages.dart';
import 'call_receipt.dart';

abstract final class ConversationBillingSignals {
  static Iterable<WalletSettlementSignal> fromMessages(
    Iterable<ConversationMessage> messages,
  ) sync* {
    for (final message in messages) {
      final single = message.receipt?.billing;
      if (single != null) yield _signal(single);
      for (final item in message.batchReceipt?.items ?? const []) {
        for (final billing in item.billing) {
          yield _signal(billing);
        }
      }
    }
  }

  static WalletSettlementSignal _signal(ReceiptBilling billing) =>
      WalletSettlementSignal(
        billing.sessionId.trim().isEmpty ? '' : 'task:${billing.sessionId}',
        jsonEncode([
          billing.state.trim().toUpperCase(),
          billing.durationSeconds,
          billing.chargedPoints,
          billing.remainingPoints,
          billing.firstMinutePoints,
          billing.blockDurationMs,
          billing.blockPoints,
        ]),
      );
}
