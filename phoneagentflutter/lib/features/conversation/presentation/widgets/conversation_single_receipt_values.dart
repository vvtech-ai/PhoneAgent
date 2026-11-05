import '../../domain/receipts/call_dialogue.dart';
import '../../domain/receipts/call_receipt.dart';
import '../../domain/receipts/native_call_receipt_presentation.dart';
import 'call_receipt_text.dart';

/// Matches single-call presentation without hashing execution metadata.
Iterable<Object?> conversationSingleReceiptValues(CallReceipt? receipt) sync* {
  yield receipt != null;
  if (receipt == null) return;
  final plan = NativeCallReceiptPresentation(receipt);
  final status = plan.status;
  yield plan.outcome;
  yield plan.title;
  yield plan.terminalIncomplete;
  if (plan.terminalIncomplete) yield plan.reason;
  yield plan.reasonOnly;
  yield plan.showContact;
  yield plan.showContact ? plan.targetLabel : '';
  final visibleReason = plan.terminalIncomplete
      ? plan.reason.isNotEmpty &&
            plan.reason != status &&
            plan.reason != plan.title &&
            plan.reason != receipt.headline
      : plan.reasonOnly ||
            receipt.fields.isEmpty &&
                plan.failed &&
                plan.reason != status &&
                plan.reason != plan.title;
  if (visibleReason) {
    yield plan.reason;
  }
  yield status;
  yield receipt.targetName;
  yield receipt.phoneNumber;
  yield receipt.headline.isNotEmpty &&
          receipt.headline != status &&
          receipt.headline != receipt.status
      ? receipt.headline
      : '';
  yield receipt.detail.isNotEmpty &&
          receipt.detail != receipt.headline &&
          receipt.detail != receipt.transcript
      ? receipt.detail
      : '';
  yield receipt.fields.length;
  for (final field in receipt.fields) {
    yield field.label;
    yield field.value;
  }
  final lines = CallDialogue.parse(receipt.transcript);
  yield lines.length;
  for (final line in lines) {
    yield line.role;
    yield line.text;
  }
  yield receipt.recordingCallId;
  final rows = receipt.billing == null
      ? const <String>[]
      : CallReceiptText.billingRows(receipt.billing!);
  yield rows.length;
  yield* rows;
}
