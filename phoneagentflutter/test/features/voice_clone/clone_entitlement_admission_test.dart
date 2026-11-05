import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_creation_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_creation_controller.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_price_policy.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  for (final entitlement in [false, null]) {
    test(
      'fresh flow admission rejects changed entitlement $entitlement',
      () async {
        var pointsReads = 0;
        final error = await refreshedCloneAdmission(
          const CloneCreationModel(
            id: '4',
            name: 'Qwen',
            pricePoints: 300,
            cloneEntitled: true,
          ),
          models: () async => [
            CloneCreationModel(
              id: '4',
              name: 'Qwen',
              pricePoints: 300,
              cloneEntitled: entitlement,
            ),
          ],
          points: () async {
            pointsReads++;
            return 900;
          },
          isCurrent: () => true,
        );
        expect(error, isNotNull);
        expect(pointsReads, 0);
      },
    );
  }
  for (final entry in <String, Object?>{
    'denied': false,
    'legacy unknown': null,
    'entitled': true,
  }.entries) {
    test('${entry.key} is independent from availability and points', () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.data = {
        'models': [
          {
            'modelId': 'QWEN_OMNI_PLUS',
            'displayName': 'Qwen',
            'available': true,
            'pricePoints': 300,
            'cloneEntitled': entry.value,
            'entitlementReason': entry.value == false
                ? 'ENTITLEMENT_DENIED'
                : null,
          },
        ],
      };
      var pointsReads = 0;
      var recordingReads = 0;
      final controller = CloneCreationController(
        ApiCloneCreationPort(
          http.api,
          points: () async {
            pointsReads++;
            return 900;
          },
          recording: () async {
            recordingReads++;
            return false;
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.select('QWEN_OMNI_PLUS');
      if (entry.value == true) {
        expect(controller.state.launch, isNotNull);
      } else {
        expect(controller.state.launch, isNull);
        expect(pointsReads, 0);
        expect(recordingReads, 0);
      }
    });
  }

  test('entitlement lookup unavailable is retryable, never denied', () async {
    final http = SyntheticAccountApi();
    addTearDown(http.api.close);
    http.data = {
      'models': [
        {
          'modelId': 'QWEN_OMNI_PLUS',
          'available': false,
          'pricePoints': 300,
          'cloneEntitled': false,
          'entitlementReason': 'ENTITLEMENT_UNAVAILABLE',
        },
      ],
    };
    final controller = CloneCreationController(
      ApiCloneCreationPort(
        http.api,
        points: () async => 900,
        recording: () async => false,
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.select('QWEN_OMNI_PLUS');
    expect(controller.state.error, contains('权益读取失败'));
    expect(controller.state.launch, isNull);
  });
}
