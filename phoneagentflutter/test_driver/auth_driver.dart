import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('.local/auth-validation');
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      if (!{'login', 'invitation'}.contains(name)) return false;
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      // File capture success only. Visual fidelity is reviewed separately.
      return bytes.isNotEmpty;
    },
    responseDataCallback: (data) async {
      final evidence = Map<String, dynamic>.from(data ?? {})
        ..remove('screenshots');
      await File(
        '${output.path}/result.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    },
  );
}
