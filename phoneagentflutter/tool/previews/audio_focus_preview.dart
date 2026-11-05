import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/settings/presentation/pages/audio_focus_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      title: 'PhoneAgent 跨模块音频演练',
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MobilePreview(child: child!),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C55ED),
      ),
      home: const AudioFocusPreviewPage(),
    ),
  );
}
