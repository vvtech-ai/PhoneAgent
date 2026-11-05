import 'package:flutter/material.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_caller_introduction_page.dart';

/// Independent pure-UI fixture: no SDK, account, permission or network port.
void main() => runApp(const _Reference());

class _Reference extends StatefulWidget {
  const _Reference();
  @override
  State<_Reference> createState() => _ReferenceState();
}

class _ReferenceState extends State<_Reference> {
  String? _result;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          const bool.fromEnvironment('UI_REFERENCE_INTRO_LARGE') ? 2 : 1,
        ),
      ),
      child: child!,
    ),
    home: _result == null
        ? TrustedCallerIntroductionPage(
            onStart: () => setState(() => _result = '开始：独立说明页未调用可信SDK'),
            onExit: () => setState(() => _result = '返回：独立说明页已关闭'),
          )
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_result!),
                    TextButton(
                      onPressed: () => setState(() => _result = null),
                      child: const Text('重新查看说明'),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
