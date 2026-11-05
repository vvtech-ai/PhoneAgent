import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_permission_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      title: 'PhoneAgent 拨号权限演练',
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MobilePreview(child: child!),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C55ED),
      ),
      home: const DialPermissionPreviewPage(),
    ),
  );
}
