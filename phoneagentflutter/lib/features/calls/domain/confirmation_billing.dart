import 'dart:convert';
import 'call_admission.dart';
import 'call_launch_request.dart';
import '../../conversation/domain/conversation_messages.dart';

abstract interface class ConfirmationBillingStore {
  Future<ConfirmationBillingSnapshot> resolve(
    ConfirmationBillingRequest request,
    ConfirmationBillingSnapshot current,
  );
}

class ConfirmationBillingSnapshot {
  const ConfirmationBillingSnapshot({this.modelTitle, this.availableBalance});
  final String? modelTitle;
  final int? availableBalance;
  Map<String, Object?> toJson() => {
    'modelTitle': modelTitle,
    'availableBalance': availableBalance,
  };
  factory ConfirmationBillingSnapshot.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid billing snapshot');
    final model = value['modelTitle'], balance = value['availableBalance'];
    if ((model != null && (model is! String || model.length > 256)) ||
        (balance != null &&
            (balance is! int || balance.abs() > 9007199254740991))) {
      throw const FormatException('Invalid billing snapshot fields');
    }
    return ConfirmationBillingSnapshot(
      modelTitle: model as String?,
      availableBalance: balance as int?,
    );
  }
  int get firstMinute => CallAdmissionPolicy.firstMinutePoints(modelTitle);
  int get sixSeconds => firstMinute ~/ 10;
  String get footer => '模型倍率已计入 · 未接通不扣 · 多路外呼每一路单独计费';
  String get rateText =>
      '接通后首分钟 $firstMinute 积分，之后每 6 秒 $sixSeconds 积分\n'
      '$footer';
  List<String> notices(int recipients) {
    final balance = availableBalance;
    if (balance == null) return const [];
    final count = recipients < 1 ? 1 : recipients;
    if (balance < firstMinute * count) {
      return count > 1
          ? ['多路积分不足', '当前积分不足以呼叫全部联系人。请减少联系人或补充积分后再试。']
          : ['当前积分不足以发起本次通话。请补充积分后再试。'];
    }
    if (balance < (firstMinute + 10 * sixSeconds) * count) {
      return [count > 1 ? '当前积分预计支持每通通话不足2分钟。' : '当前积分预计支持本次通话不足2分钟。'];
    }
    return const [];
  }
}

class ConfirmationBillingRequest {
  ConfirmationBillingRequest(
    this.sessionId,
    Iterable<String> aliases, {
    this.captureCurrent = true,
  }) : aliases = List.unmodifiable(
         aliases.where((s) => s.trim().isNotEmpty).toSet(),
       );
  final String sessionId;
  final List<String> aliases;
  final bool captureCurrent;
  String get identity => jsonEncode([sessionId, aliases, captureCurrent]);
  static ConfirmationBillingRequest forMessage(
    String sessionId,
    ConversationMessage message,
    int ordinal,
  ) {
    final confirmation = message.confirmation!;
    final source = confirmation.sourceSpec;
    final request = CallLaunchRequest(
      sessionId: sessionId,
      toolId: message.toolCallId ?? '',
      commandId: message.commandId ?? '',
      ordinal: ordinal,
      spec: {
        ...source,
        'targetName': confirmation.targetName,
        'phoneNumber': confirmation.phoneNumber,
        'primaryGoal': confirmation.primaryGoal,
        'summaryLines': source['summaryLines'] ?? confirmation.summaryLines,
        if (confirmation.fromBatchTool)
          'recipientCount': confirmation.recipientCount,
      },
    );
    return ConfirmationBillingRequest(sessionId, request.aliases);
  }

  static bool currentBatch(
    ConversationMessage message,
    List<ConversationMessage> messages,
  ) {
    if (message.batchConfirmation?.capturesBilling != true) return false;
    return messages.reversed
            .where(
              (m) =>
                  m.confirmation != null ||
                  m.batchConfirmation != null ||
                  m.receipt != null ||
                  m.batchReceipt != null,
            )
            .firstOrNull
            ?.id ==
        message.id;
  }

  @override
  bool operator ==(Object other) =>
      other is ConfirmationBillingRequest && identity == other.identity;
  @override
  int get hashCode => identity.hashCode;
}
