import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/app_update/presentation/pages/startup_update_preview_page.dart';

void main() => runApp(
  ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MobilePreview(child: child!),
      home: const StartupUpdateScenariosPage(),
    ),
  ),
);
