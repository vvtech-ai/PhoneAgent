import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/conversation/presentation/pages/receipt_preview_page.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MobilePreview(child: child!),
    home: const ReceiptPreviewPage(),
  ),
);
