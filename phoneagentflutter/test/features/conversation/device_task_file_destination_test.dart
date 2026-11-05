import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/artifacts/device_task_file_destination.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'task_artifact_test.dart' show descriptor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/task_files');
  final calls = <MethodCall>[];
  String? result;
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'save' ? result : null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'system save cancellation is not success; completed export preserves location and type',
    () async {
      const port = DeviceTaskFileDestination();
      final a = TaskArtifact.parse(descriptor)!;
      result = null;
      expect(await port.save('0' * 32, a, Uint8List.fromList([1, 2])), isNull);
      result = 'content://synthetic/file';
      final saved = await port.save('1' * 32, a, Uint8List.fromList([1, 2]));
      expect(saved!.location, result);
      expect(calls.last.arguments['mime'], a.mimeType);
      expect(calls.last.arguments['name'], '任务模板.docx');
      await port.open(saved);
      await port.cancel('1' * 32);
      expect(calls.map((c) => c.method), ['save', 'save', 'open', 'cancel']);
    },
  );
}
