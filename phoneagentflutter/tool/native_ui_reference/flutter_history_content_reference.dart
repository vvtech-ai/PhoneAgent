import 'package:flutter/material.dart';
import 'history_font_diagnostics.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';

void main({
  bool largeText = const bool.fromEnvironment('UI_REFERENCE_HISTORY_LARGE'),
  bool empty = const bool.fromEnvironment('UI_REFERENCE_HISTORY_EMPTY'),
  String initial = const String.fromEnvironment(
    'UI_REFERENCE_HISTORY_INITIAL',
    defaultValue: 'none',
  ),
}) => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(platform: TargetPlatform.iOS),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
      child: child!,
    ),
    home: _HistoryReference(empty: empty, initial: initial),
  ),
);

class _HistoryReference extends StatefulWidget {
  const _HistoryReference({required this.empty, required this.initial});
  final bool empty;
  final String initial;
  @override
  State<_HistoryReference> createState() => _HistoryReferenceState();
}

class _HistoryReferenceState extends State<_HistoryReference> {
  bool _closed = false;
  bool _waiting = false;
  late String _initial;
  @override
  void initState() {
    super.initState();
    if (!const {'none', 'loading', 'error'}.contains(widget.initial) ||
        (widget.empty && widget.initial != 'none')) {
      throw ArgumentError('Invalid synthetic history reference state');
    }
    _initial = widget.initial;
  }

  Future<void> _retry() async {
    if (_closed || _waiting) return;
    setState(() {
      _waiting = true;
      _initial = 'loading';
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _closed) return;
    setState(() {
      _waiting = false;
      _initial = 'none';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initial == 'none' &&
        MediaQuery.textScalerOf(context).scale(14) == 14) {
      printHistoryFontDiagnostics(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TranslationHistoryPage.background,
    body: SafeArea(
      child: _closed
          ? const Center(child: Text('合成历史展示已返回'))
          : TranslationHistoryPage(
              state: TranslationHistoryState(
                loading: _initial == 'loading',
                failed: _initial == 'error',
                content: _initial != 'none'
                    ? null
                    : TranslationHistoryContent(
                        '合成翻译对象',
                        '+12025550123',
                        '9月16日 11:00',
                        '00:12',
                        widget.empty
                            ? const []
                            : const [
                                TranslationRow(
                                  true,
                                  '请确认今天的营业时间。',
                                  'Please confirm today’s opening hours.',
                                ),
                                TranslationRow(
                                  false,
                                  '今天营业到晚上八点。',
                                  'We are open until eight this evening.',
                                ),
                              ],
                        false,
                      ),
              ),
              onClose: () => setState(() => _closed = true),
              onRetry: _retry,
            ),
    ),
  );
}
