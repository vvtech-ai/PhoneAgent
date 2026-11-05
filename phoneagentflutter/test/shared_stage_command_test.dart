import 'package:flutter_test/flutter_test.dart';
import '../tool/validation/shared_stage_command.dart';

void main() {
  test(
    'focused group retains attach-only and exact target, unknown group fails',
    () {
      for (final group in [
        'developer',
        'network-recovery',
        'keyboard',
        'initialization',
        'confirmation',
        'voice-clone',
        'migration-increment',
        'ui-consistency',
      ]) {
        final args = sharedStageArguments(
          platform: 'ios',
          device: 'device',
          vmService: Uri.parse('http://127.0.0.1:12345/example=/'),
          group: group,
        );
        expect(
          args,
          contains(
            '--target=integration_test/${group.replaceAll('-', '_')}_stage_test.dart',
          ),
        );
        expect(args, contains('--keep-app-running'));
        expect(
          args.any((arg) => arg.startsWith('--use-existing-app=')),
          isTrue,
        );
      }
      expect(
        () => sharedStageArguments(
          platform: 'ios',
          device: 'device',
          vmService: Uri.parse('http://127.0.0.1:12345/example=/'),
          group: '../other',
        ),
        throwsArgumentError,
      );
    },
  );
  for (final platform in ['android', 'ios']) {
    test('$platform attaches only and preserves app after test', () {
      final args = sharedStageArguments(
        platform: platform,
        device: 'explicit-device',
        vmService: Uri.parse('http://127.0.0.1:12345/example=/'),
      );
      expect(args, contains('--keep-app-running'));
      expect(
        args,
        contains('--use-existing-app=http://127.0.0.1:12345/example=/'),
      );
      expect(args, isNot(contains('--no-keep-app-running')));
      expect(args, containsAllInOrder(['-d', 'explicit-device']));
    });
  }
  test('rejects implicit device and unsupported platform', () {
    for (final pair in [('android', ''), ('web', 'device')]) {
      expect(
        () => sharedStageArguments(
          platform: pair.$1,
          device: pair.$2,
          vmService: Uri.parse('http://127.0.0.1:12345/example=/'),
        ),
        throwsArgumentError,
      );
    }
  });
  test('rejects remote or credential-bearing service endpoints', () {
    for (final uri in [
      'http://example.com:12345/',
      'http://127.0.0.1/',
      'http://user:secret@127.0.0.1:12345/',
      'http://127.0.0.1:12345/?token=secret',
    ]) {
      expect(
        () => sharedStageArguments(
          platform: 'android',
          device: 'device',
          vmService: Uri.parse(uri),
        ),
        throwsArgumentError,
      );
    }
  });
}
