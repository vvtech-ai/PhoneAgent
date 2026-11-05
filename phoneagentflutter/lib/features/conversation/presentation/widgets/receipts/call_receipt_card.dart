import 'package:flutter/material.dart';
import '../../../../../core/design/receipt_tokens.dart';
import '../../../domain/receipts/call_dialogue.dart';
import '../../../domain/receipts/call_receipt.dart';
import '../../../domain/receipts/call_receipt_status.dart';
import '../../../domain/receipts/native_call_receipt_presentation.dart';
import 'receipt_sections.dart';

bool _isDiagnosticField(ReceiptField field) {
  final key = field.key.trim().toLowerCase();
  final label = field.label.trim();
  return const [
        'diagnostic',
        'trace',
        'debug',
        'exception',
        'stack',
        'errorcode',
        'terminationcause',
      ].any(key.contains) ||
      const ['诊断', '调试', '错误', '异常', '堆栈', '技术'].any(label.contains);
}

bool _hasKnownDiagnosticMarker(String value) => RegExp(
  r'terminationCause|agentReason|resultReason|stackTrace|traceId|errorCode|Exception|\b(?:SYSTEM_STOP|SIP_ERROR|PHONE_AGENT_ERROR|MODEL_ERROR|SERVICE_UNAVAILABLE|HTTP_ERROR)\b',
  caseSensitive: false,
).hasMatch(value);

bool _hasTechnicalMarker(String value) =>
    _hasKnownDiagnosticMarker(value) ||
    RegExp(r'\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b').hasMatch(value);

bool _isShortBusinessText(String value) {
  final text = value.trim();
  return text.isNotEmpty &&
      text.runes.length <= 80 &&
      !text.contains('\n') &&
      CallDialogue.parse(text).isEmpty &&
      !_hasTechnicalMarker(text);
}

bool _showTaskField(ReceiptField field) =>
    !_isDiagnosticField(field) &&
    !_hasKnownDiagnosticMarker(field.label) &&
    !_hasKnownDiagnosticMarker(field.value) &&
    (!(field.key.toLowerCase().contains('reason') ||
            field.label.contains('原因')) ||
        _isShortBusinessText(field.value));

class CallReceiptCard extends StatelessWidget {
  const CallReceiptCard({
    super.key,
    required this.receipt,
    this.recordingBuilder,
  });
  final CallReceipt receipt;
  final Widget Function(String callId, bool compact)? recordingBuilder;
  @override
  Widget build(BuildContext context) {
    final plan = NativeCallReceiptPresentation(receipt);
    final outcome = plan.cardOutcome;
    final status = plan.status;
    final structured = receipt.fields.isNotEmpty;
    final title = plan.title;
    final lines = CallDialogue.parse(receipt.transcript);
    final protectTaskReason =
        plan.executionError ||
        (plan.task &&
            (plan.failed || plan.outcome == CallReceiptOutcome.unclear));
    final shortHeadline =
        protectTaskReason &&
            receipt.headline != receipt.metadata['agentReason'] &&
            receipt.headline != receipt.metadata['resultReason'] &&
            _isShortBusinessText(receipt.headline)
        ? receipt.headline
        : '';
    final shortDetail =
        protectTaskReason &&
            receipt.detail != receipt.metadata['agentReason'] &&
            receipt.detail != receipt.metadata['resultReason'] &&
            _isShortBusinessText(receipt.detail)
        ? receipt.detail
        : '';
    final displayReason = protectTaskReason
        ? shortDetail.isNotEmpty && shortDetail != shortHeadline
              ? shortDetail
              : plan.executionError
              ? shortHeadline
              : ''
        : plan.reason;
    final reasonOnlyText = protectTaskReason
        ? displayReason.isNotEmpty
              ? displayReason
              : shortHeadline.isNotEmpty &&
                    shortHeadline != '通话已结束' &&
                    shortHeadline != status &&
                    shortHeadline != title
              ? shortHeadline
              : status
        : plan.reason;
    final reasonInFields =
        protectTaskReason &&
        receipt.fields.any(
          (field) => _showTaskField(field) && field.value == displayReason,
        );
    final (colors, tint) = switch (outcome) {
      CallReceiptOutcome.completed => (
        ReceiptTokens.success,
        const Color(0xFF2E7D32),
      ),
      CallReceiptOutcome.failed || CallReceiptOutcome.cancelled => (
        ReceiptTokens.failure,
        const Color(0xFFC62828),
      ),
      CallReceiptOutcome.unclear => (
        ReceiptTokens.unclear,
        const Color(0xFF8A6D1D),
      ),
      CallReceiptOutcome.running => (
        const [Color(0xFFF7FBFF), Color(0xFFEDF5FF)],
        ReceiptTokens.blue,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isNotEmpty)
          ReceiptShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '通话转写',
                  style: ReceiptTokens.caption.copyWith(
                    color: ReceiptTokens.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ReceiptTranscript(lines: lines),
              ],
            ),
          ),
        if (receipt.recordingCallId case final id?)
          if (recordingBuilder != null) recordingBuilder!(id, false),
        ReceiptShell(
          gradient: colors,
          borderColor: switch (outcome) {
            CallReceiptOutcome.completed => const Color(0x3334C759),
            CallReceiptOutcome.failed ||
            CallReceiptOutcome.cancelled => const Color(0x33E14D46),
            CallReceiptOutcome.unclear => const Color(0x33C99700),
            CallReceiptOutcome.running => ReceiptTokens.border,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ReceiptTokens.title.copyWith(
                  color: tint,
                  height: 18 / 14,
                ),
              ),
              if (plan.reasonOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    reasonOnlyText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: Color(0xFF333333),
                    ),
                  ),
                )
              else ...[
                if (structured)
                  for (final field in receipt.fields)
                    if (!protectTaskReason || _showTaskField(field))
                      ReceiptFieldRow(field.label, field.value),
                ReceiptFieldRow('状态', status, color: tint),
                if (!structured &&
                    plan.showContact &&
                    receipt.targetName.isNotEmpty)
                  ReceiptFieldRow(plan.targetLabel, receipt.targetName),
                if (!structured &&
                    !plan.booking &&
                    plan.showContact &&
                    receipt.phoneNumber.isNotEmpty)
                  ReceiptFieldRow('电话', receipt.phoneNumber),
                if ((protectTaskReason
                        ? !plan.executionError && shortHeadline.isNotEmpty
                        : (!structured || plan.terminalIncomplete) &&
                              (!plan.failureTone || plan.terminalIncomplete)) &&
                    receipt.headline.isNotEmpty &&
                    receipt.headline != title &&
                    receipt.headline != status &&
                    receipt.headline != receipt.status &&
                    receipt.headline != '通话已结束' &&
                    receipt.headline != '结果未确认')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      receipt.headline,
                      semanticsLabel: receipt.headline,
                      style: ReceiptTokens.body,
                    ),
                  ),
                if (!protectTaskReason &&
                    !structured &&
                    !plan.failureTone &&
                    receipt.detail.isNotEmpty &&
                    receipt.detail != receipt.headline &&
                    (receipt.detail != receipt.transcript || lines.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      receipt.detail,
                      semanticsLabel: receipt.detail,
                      style: ReceiptTokens.body,
                    ),
                  ),
                if (plan.terminalIncomplete &&
                    displayReason.isNotEmpty &&
                    !reasonInFields &&
                    displayReason != status &&
                    displayReason != title &&
                    displayReason != receipt.headline)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '原因',
                          style: ReceiptTokens.body.copyWith(
                            color: const Color(0xFF666666),
                          ),
                        ),
                        SelectableText(
                          displayReason,
                          style: ReceiptTokens.body,
                        ),
                      ],
                    ),
                  )
                else if ((!structured || protectTaskReason) &&
                    plan.failed &&
                    displayReason.isNotEmpty &&
                    !reasonInFields &&
                    displayReason != status &&
                    displayReason != title)
                  ReceiptFieldRow('原因', displayReason),
              ],
              if (receipt.billing case final billing?)
                ReceiptBillingSection(billing: billing),
            ],
          ),
        ),
      ],
    );
  }
}
