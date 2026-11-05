import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final platform = Platform.environment['STAGE_PLATFORM'];
  if (!{'android', 'ios'}.contains(platform)) {
    throw ArgumentError('STAGE_PLATFORM must explicitly be android or ios');
  }
  final group = Platform.environment['STAGE_GROUP'] ?? 'all';
  if (!{
    'all',
    'developer',
    'network-recovery',
    'task-flow',
    'keyboard',
    'auth-onboarding',
    'initialization',
    'confirmation',
    'voice-clone',
    'migration-increment',
    'ui-consistency',
  }.contains(group)) {
    throw ArgumentError('Unknown stage group');
  }
  // Focused runs must not overwrite the previous complete stage's report.
  final output = Directory(
    group == 'all'
        ? '.local/shared-stage/$platform'
        : '.local/shared-stage/$group/$platform',
  );
  await output.create(recursive: true);
  final screenshots = <Map<String, Object>>[];
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [arguments]) async {
      if (!RegExp(r'^\d{2}-[a-z-]+$').hasMatch(name)) return false;
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      // Container validity is not visual acceptance; inspect screenshots too.
      if (bytes.length < 4096 ||
          bytes.take(8).join(',') != '137,80,78,71,13,10,26,10') {
        return false;
      }
      final header = ByteData.sublistView(Uint8List.fromList(bytes), 16, 24);
      final width = header.getUint32(0);
      final height = header.getUint32(4);
      screenshots.add({
        'name': name,
        'width': width,
        'height': height,
        'bytes': bytes.length,
      });
      return width >= 300 && height >= 500;
    },
    responseDataCallback: (data) async {
      final evidence = Map<String, dynamic>.from(data ?? {})
        ..remove('screenshots');
      evidence['screenshotFiles'] = screenshots;
      evidence['collectedAt'] = DateTime.now().toUtc().toIso8601String();
      await File(
        '${output.path}/result.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    },
  );
}
