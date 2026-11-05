import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_sdk_diagnosis.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';

void main() {
  test('only 1000 and 2006 require server judgment', () {
    for (final code in [-1, 1000, 1001, 1003, 2002, 2003, 2006, 9999]) {
      expect(
        CloneSdkDiagnosis.requiresServerQuery(code),
        code == 1000 || code == 2006,
      );
    }
  });
  test(
    'known subcode overrides broad SDK category without retaining reason',
    () {
      final result = CloneSdkDiagnosis.observation(
        const IdentityCaptureResult(
          1001,
          reason: 'sensitive-prefix z1030; trailing',
        ),
        const Duration(seconds: 1),
      );
      expect(result.sdkSubCode, 'Z1030');
      expect(result.reasonCategory, 'MICROPHONE_PERMISSION');
      expect(result.sdkElapsedMs, 1000);
    },
  );
  test('subcode token boundaries and code fallbacks match v65', () {
    for (final reason in ['AZ1030', 'Z1030X', '_Z1030', 'Z1030_more']) {
      expect(
        CloneSdkDiagnosis.observation(
          IdentityCaptureResult(1000, reason: reason),
          Duration.zero,
        ).sdkSubCode,
        null,
      );
    }
    const expected = {
      1000: 'SUCCESS',
      1003: 'USER_CANCELLED',
      2002: 'NETWORK_ACCESS',
      2003: 'DEVICE_TIME',
      2006: 'VERIFICATION_REJECTED',
      1001: 'SDK_INTERNAL',
      -1: 'UNKNOWN',
    };
    for (final entry in expected.entries) {
      expect(
        CloneSdkDiagnosis.observation(
          IdentityCaptureResult(entry.key),
          Duration.zero,
        ).reasonCategory,
        entry.value,
      );
    }
  });
  test('device environment and elapsed are bounded for DTO contract', () {
    final result = CloneSdkDiagnosis.observation(
      IdentityCaptureResult(
        10000,
        deviceModel: '  ${'a' * 70}\n ',
        networkType: 'SSID is not allowed',
      ),
      const Duration(hours: 2),
    );
    expect(result.deviceModel.length, 64);
    expect(result.sdkCode, -1);
    expect(result.networkType, 'NONE');
    expect(result.sdkElapsedMs, 3600000);
    final empty = CloneSdkDiagnosis.observation(
      const IdentityCaptureResult(-2, deviceModel: ' \n '),
      const Duration(seconds: -1),
    );
    expect(empty.deviceModel, 'unknown');
    expect(empty.sdkElapsedMs, 0);
  });
}
