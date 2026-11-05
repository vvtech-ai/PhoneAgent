/// Attach-only driver: building/installing is a separate, explicit operation.
/// Never lets `flutter drive` own an installed package or its uninstall cleanup.
List<String> sharedStageArguments({
  required String platform,
  required String device,
  required Uri vmService,
  String group = 'all',
}) {
  const targets = {
    'all': 'integration_test/shared_stage_test.dart',
    'ui-consistency': 'integration_test/ui_consistency_stage_test.dart',
    'developer': 'integration_test/developer_stage_test.dart',
    'network-recovery': 'integration_test/network_recovery_stage_test.dart',
    'task-flow': 'integration_test/task_flow_stage_test.dart',
    'keyboard': 'integration_test/keyboard_stage_test.dart',
    'auth-onboarding': 'integration_test/auth_onboarding_alignment_test.dart',
    'initialization': 'integration_test/initialization_stage_test.dart',
    'confirmation': 'integration_test/confirmation_stage_test.dart',
    'voice-clone': 'integration_test/voice_clone_stage_test.dart',
    'migration-increment':
        'integration_test/migration_increment_stage_test.dart',
  };
  if (!targets.containsKey(group)) throw ArgumentError('Unknown stage group');
  if (!{'android', 'ios'}.contains(platform) || device.trim().isEmpty) {
    throw ArgumentError('Specify android/ios and one explicit device ID');
  }
  if (vmService.scheme != 'http' ||
      vmService.host != '127.0.0.1' ||
      !vmService.hasPort ||
      vmService.userInfo.isNotEmpty ||
      vmService.hasQuery ||
      vmService.hasFragment) {
    throw ArgumentError('Use the authenticated local 127.0.0.1 VM Service URL');
  }
  return [
    'drive',
    '--no-pub',
    '--keep-app-running',
    '--use-existing-app=$vmService',
    '--driver=test_driver/shared_stage_driver.dart',
    '--target=${targets[group]}',
    '-d',
    device,
  ];
}
