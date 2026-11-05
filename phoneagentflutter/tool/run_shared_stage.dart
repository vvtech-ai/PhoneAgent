import 'dart:io';
import 'validation/shared_stage_command.dart';

/// Run after explicitly installing and launching the test binary without
/// uninstalling the app. The VM URL remains in local process arguments only.
/// Usage: dart run tool/run_shared_stage.dart android DEVICE VM_URL [FLUTTER]
/// STAGE_GROUP=developer|network-recovery selects a focused test entry.
Future<void> main(List<String> arguments) async {
  if (arguments.length < 3 || arguments.length > 4) {
    stderr.writeln('Usage: <android|ios> <device-id> <local-vm-url> [flutter]');
    exitCode = 64;
    return;
  }
  final command = sharedStageArguments(
    platform: arguments[0],
    device: arguments[1],
    vmService: Uri.parse(arguments[2]),
    group: Platform.environment['STAGE_GROUP'] ?? 'all',
  );
  final child = await Process.start(
    arguments.length == 4 ? arguments[3] : 'flutter',
    command,
    environment: {'STAGE_PLATFORM': arguments[0]},
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await child.exitCode;
}
