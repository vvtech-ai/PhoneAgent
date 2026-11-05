import 'package:flutter/material.dart';

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
    final enabled = callback != null;
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: primary && enabled
                ? const [Color(0xFF0A84FF), Color(0xFF0071EB)]
                : const [Color(0xFFF2F4F7), Color(0xFFE8ECF2)],
          ),
        ),
        child: TextButton(
          key: key,
          onPressed: callback == null
              ? null
              : () {
                  if (context.mounted &&
                      ModalRoute.of(context)?.isCurrent == true) {
                    callback();
                  }
                },
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: radius),
            side: BorderSide.none,
            foregroundColor: primary ? Colors.white : const Color(0xFF344054),
            disabledForegroundColor: const Color(0xFF9CA7B5),
            textStyle: const TextStyle(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
