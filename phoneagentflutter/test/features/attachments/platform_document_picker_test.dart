import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/platform_document_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/file_selector');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android document picker accepts provider MIME variants for Word and Excel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<Object?, Object?>? arguments;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'openFile');
        arguments = call.arguments as Map<Object?, Object?>;
        return <String>[];
      });

      expect(await const PlatformDocumentPicker().pick(), isEmpty);
      final groups = arguments!['acceptedTypeGroups'] as List<Object?>;
      final group = groups.single as Map<Object?, Object?>;
      expect(group['mimeTypes'], contains('application/*'));
      expect(group['extensions'], ['docx', 'xlsx']);
    },
  );
}
