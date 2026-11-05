import 'package:flutter/material.dart';
import 'native_gradient_action.dart';
import 'native_dialog_body.dart';

/// Shared non-sheet surface. Business owners retain route and request state.
enum NativeDialogKind { explanation, confirmation }

class NativeBusinessDialog extends StatelessWidget {
  const NativeBusinessDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.message = '',
    this.content,
    this.error = '',
    this.dismissLabel = '取消',
    this.onDismiss,
    this.showDismiss = true,
    this.kind = NativeDialogKind.explanation,
    this.danger = false,
    this.allowBack = true,
    this.confirmKey,
    this.dismissKey,
    this.surfaceKey,
    this.actions,
    this.dismissBackgroundColor,
    this.dismissForegroundColor,
    this.confirmBackgroundColor,
    this.confirmForegroundColor,
  });

  final String title, message, error, confirmLabel, dismissLabel;
  final Widget? content;
  final VoidCallback? onConfirm, onDismiss;
  final NativeDialogKind kind;
  final bool danger, allowBack, showDismiss;
  final Key? confirmKey, dismissKey, surfaceKey;
  final Widget? actions;
  final Color? dismissBackgroundColor, dismissForegroundColor;
  final Color? confirmBackgroundColor, confirmForegroundColor;

  VoidCallback? _current(BuildContext context, VoidCallback? action) =>
      action == null
      ? null
      : () {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            action();
          }
        };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowBack,
    child: Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        key: surfaceKey,
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                NativeDialogBody(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    color: Color(0xFF6E6E73),
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: 8),
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    color: Color(0xFF6E6E73),
                  ),
                  child: content!,
                ),
              ],
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    key: const Key('business-dialog-error'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: Color(0xFFE14D46),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              actions ??
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDismiss) ...[
                          Expanded(
                            child: NativeGradientAction(
                              actionKey: dismissKey,
                              label: dismissLabel,
                              tone: NativeActionTone.secondary,
                              backgroundColor: dismissBackgroundColor,
                              foregroundColor: dismissForegroundColor,
                              onPressed: _current(context, onDismiss),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: NativeGradientAction(
                            actionKey: confirmKey,
                            label: confirmLabel,
                            backgroundColor: confirmBackgroundColor,
                            foregroundColor: confirmForegroundColor,
                            tone:
                                kind == NativeDialogKind.confirmation && danger
                                ? NativeActionTone.danger
                                : NativeActionTone.primary,
                            onPressed: _current(context, onConfirm),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}
