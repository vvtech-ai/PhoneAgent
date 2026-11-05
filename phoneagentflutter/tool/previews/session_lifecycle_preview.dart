import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'shell_preview.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MobilePreview(child: ShellPreviewPage(sessionControls: true)),
    ),
  );
}
