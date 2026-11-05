import 'package:flutter/material.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_preview_route.dart';

/// Tool-only launcher. Normal dial pages never navigate here.
class TranslationCallPreviewLauncher extends StatelessWidget {
  const TranslationCallPreviewLauncher({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('翻译通话演练（MOCK）')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MOCK · 不使用输入号码、不发起真实通话、录音、媒体或计费'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final result = await openTranslationCallPreview(context);
                if (context.mounted && result != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result)));
                }
              },
              child: const Text('进入翻译通话演练（MOCK）'),
            ),
          ],
        ),
      ),
    ),
  );
}
