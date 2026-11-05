import 'package:flutter/material.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';

/// Production language picker with memory selection only; no external ports.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: const _Root(),
  ),
);

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String _code = 'zh', _result = '合成语种已返回：未选择';
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TranslationLanguagePage(caller: true, selected: _code),
      ),
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (code != null) {
        _code = code;
        _result = '合成语种已返回：$code';
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_result),
            TextButton(
              onPressed: _opening ? null : _open,
              child: const Text('重新选择语言'),
            ),
          ],
        ),
      ),
    ),
  );
}
