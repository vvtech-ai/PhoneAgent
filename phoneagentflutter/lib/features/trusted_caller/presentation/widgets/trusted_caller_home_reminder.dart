import 'package:flutter/material.dart';

/// Compact, title-free follow-up to the native trusted-callee guide.
class TrustedCallerHomeReminder extends StatelessWidget {
  const TrustedCallerHomeReminder({super.key, required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Dialog(
    key: const Key('trusted-home-reminder'),
    backgroundColor: const Color(0xF5FFFFFF),
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    elevation: 18,
    child: SizedBox(
      width: 280,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '你可以稍后在设置中开启可信通信被叫。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 21 / 14,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A84FF), Color(0xFF0071EB)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: SizedBox(
                height: 52,
                child: TextButton(
                  key: const Key('trusted-home-reminder-confirm'),
                  onPressed: onConfirm,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: TextStyle(
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.labelLarge?.fontFamily,
                      fontSize: 16,
                      height: 22 / 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('知道了', textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
