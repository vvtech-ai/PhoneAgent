import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/domain/wallet_settlement_sync.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/conversation_billing_signals.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);
const _a = WalletSettlementSignal('task:a', 'v1');
const _b = WalletSettlementSignal('task:b', 'v1');
void main() {
  test('empty, invalid and ordinary conversation do not refresh', () async {
    var calls = 0;
    final sync = WalletSettlementSync(
      refresh: () async {
        calls++;
      },
    );
    addTearDown(sync.close);
    sync.observe(const [
      WalletSettlementSignal('', 'x'),
      WalletSettlementSignal('x', ''),
    ]);
    sync.observe(
      ConversationBillingSignals.fromMessages(const [
        ConversationMessage(
          id: 'text',
          role: MessageRole.assistant,
          text: '完成了',
        ),
      ]),
    );
    await _flush();
    expect(calls, 0);
  });
  test('bursts, reorder and old version replay deduplicate', () async {
    var calls = 0;
    final sync = WalletSettlementSync(
      refresh: () async {
        calls++;
      },
    );
    addTearDown(sync.close);
    sync.observe([_a]);
    sync.observe([_b, _a]);
    await _flush();
    expect(calls, 1);
    sync.observe([_a, _b]);
    await _flush();
    expect(calls, 1);
    sync.observe([const WalletSettlementSignal('task:a', 'v2')]);
    await _flush();
    expect(calls, 2);
    sync.observe([_a]);
    await _flush();
    expect(calls, 2);
  });
  test('changes during a refresh queue exactly one trailing refresh', () async {
    var calls = 0;
    final gate = Completer<void>();
    final sync = WalletSettlementSync(
      refresh: () async {
        calls++;
        if (calls == 1) await gate.future;
      },
    );
    addTearDown(sync.close);
    sync.observe([_a]);
    await _flush();
    sync.observe([_b]);
    sync.observe([const WalletSettlementSignal('task:c', 'v1')]);
    expect(calls, 1);
    gate.complete();
    await _flush();
    expect(calls, 2);
  });
  test('failure never loops; a genuinely new event can refresh', () async {
    var calls = 0;
    final sync = WalletSettlementSync(
      refresh: () async {
        calls++;
        throw StateError('synthetic');
      },
    );
    addTearDown(sync.close);
    sync.observe([_a]);
    await _flush();
    sync.observe([_a]);
    await _flush();
    expect(calls, 1);
    sync.observe([_b]);
    await _flush();
    expect(calls, 2);
  });
  for (final beforeStart in [true, false]) {
    test('close drops queued work beforeStart=$beforeStart', () async {
      var calls = 0;
      final gate = Completer<void>();
      final sync = WalletSettlementSync(
        refresh: () async {
          calls++;
          await gate.future;
        },
      );
      sync.observe([_a]);
      if (!beforeStart) await _flush();
      sync.observe([_b]);
      sync.close();
      gate.complete();
      sync.observe([const WalletSettlementSignal('task:c', 'v1')]);
      await _flush();
      expect(calls, beforeStart ? 0 : 1);
    });
  }
  test('separate account lifetimes do not share seen identities', () async {
    var a = 0, b = 0;
    final first = WalletSettlementSync(
      refresh: () async {
        a++;
      },
    );
    final second = WalletSettlementSync(
      refresh: () async {
        b++;
      },
    );
    first.observe([_a]);
    second.observe([_a]);
    await _flush();
    expect([a, b], [1, 1]);
    first.close();
    second.close();
  });
  test(
    'single and batch billing emit same identity and exact version',
    () async {
      const billing = ReceiptBilling(
        sessionId: 'billing',
        state: 'SETTLED',
        remainingPoints: 1,
      );
      final messages = [
        ConversationMessage(
          id: 'single',
          role: MessageRole.assistant,
          text: '',
          receipt: CallReceipt(
            attemptId: 'attempt',
            status: 'COMPLETED',
            billing: billing,
          ),
        ),
        ConversationMessage(
          id: 'batch',
          role: MessageRole.assistant,
          text: '',
          batchReceipt: BatchReceipt.fromJson({
            'items': [
              {
                'billingSummaries': [
                  {
                    'billingSessionId': 'billing',
                    'billingState': 'settled',
                    'remainingPoints': 1,
                  },
                ],
              },
            ],
          }, fallbackId: 'batch'),
        ),
      ];
      final signals = ConversationBillingSignals.fromMessages(
        messages,
      ).toList();
      expect(signals.length, 2);
      expect(signals.first.identity, signals.last.identity);
      expect(signals.first.version, signals.last.version);
      var queries = 0;
      final sync = WalletSettlementSync(
        refresh: () async {
          queries++;
        },
      );
      addTearDown(sync.close);
      sync.observe(signals);
      await _flush();
      expect(queries, 1);
    },
  );
}
