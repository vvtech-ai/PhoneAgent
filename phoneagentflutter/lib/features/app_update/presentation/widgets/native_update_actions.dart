import 'package:flutter/material.dart';
import '../../../../core/design/native_gradient_action.dart';

/// OTA actions own their clipping and background; the gap is never painted.
class NativeUpdateActions extends StatelessWidget {
  const NativeUpdateActions({
    super.key,
    required this.primary,
    required this.primaryKey,
    required this.onPrimary,
    required this.later,
    required this.force,
    this.laterKey,
    this.onLater,
  });
  final String primary, later;
  final Key primaryKey;
  final Key? laterKey;
  final bool force;
  final VoidCallback? onPrimary, onLater;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!force) ...[
          Expanded(child: _action(context, later, laterKey, onLater, false)),
          const SizedBox(width: 12),
        ],
        Expanded(child: _action(context, primary, primaryKey, onPrimary, true)),
      ],
    ),
  );

  Widget _action(
    BuildContext context,
    String label,
    Key? key,
    VoidCallback? callback,
    bool primary,
  ) {
    return NativeGradientAction(
      actionKey: key,
      tone: primary ? NativeActionTone.primary : NativeActionTone.secondary,
      onPressed: callback == null
          ? null
          : () {
              if (context.mounted &&
                  ModalRoute.of(context)?.isCurrent == true) {
                callback();
              }
            },
      label: label,
    );
  }
}
