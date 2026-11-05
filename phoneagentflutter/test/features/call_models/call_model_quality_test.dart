import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_quality_repository.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_quality_controller.dart';

class _Quality implements CallModelQualityRepository {
  final pending = <Completer<Map<String, CallModelReading>>>[];
  @override
  Future<Map<String, CallModelReading>> refresh() {
    final next = Completer<Map<String, CallModelReading>>();
    pending.add(next);
    return next.future;
  }
}

void main() {
  test('v71 latency uses catalog modelId, not shared provider protocol', () {
    final readings = ApiCallModelQualityRepository.readings({
      'models': [
        {
          'provider': 'QWEN_OMNI_PLUS',
          'modelId': 'qwen-current',
          'available': true,
          'latencyMs': 123,
        },
        {
          'provider': 'QWEN_OMNI_PLUS',
          'modelId': 'qwen-other',
          'available': true,
          'latencyMs': 456,
        },
      ],
    });
    expect(readings['QWEN-CURRENT']!.latencyMs, 123);
    expect(readings['QWEN-OTHER']!.latencyMs, 456);
    expect(readings.containsKey('QWEN_OMNI_PLUS'), isFalse);
  });
  test('native thresholds and unavailable preserve boundaries', () {
    for (final entry in {
      0: CallModelQuality.good,
      199: CallModelQuality.good,
      200: CallModelQuality.fair,
      499: CallModelQuality.fair,
      500: CallModelQuality.high,
    }.entries) {
      expect(
        CallModelReading.probe(available: true, latencyMs: entry.key).quality,
        entry.value,
      );
    }
    for (final reading in [
      CallModelReading.probe(available: true, latencyMs: -1),
      CallModelReading.probe(available: false, latencyMs: 100),
      const CallModelReading.unavailable(),
    ]) {
      expect(reading.latencyMs, isNull);
      expect(reading.quality, CallModelQuality.unavailable);
    }
  });
  test(
    'DTO aliases strings unknown missing and invalid never invent readings',
    () {
      final result = ApiCallModelQualityRepository.readings({
        'models': [
          {
            'provider': ' qwen_omni_flash ',
            'available': true,
            'latencyMs': '199',
          },
          {'provider': 'DOUBAO_AUDIO', 'available': false, 'latencyMs': 5},
        ],
      });
      expect(result['QWEN_OMNI_PLUS']!.latencyMs, 199);
      expect(result['DOUBAO_AUDIO']!.latencyMs, isNull);
      expect(result.containsKey('SEEDUPLEX_3_0'), isFalse);
      for (final dto in [
        {'models': null},
        {
          'models': [
            {'provider': '', 'available': true},
          ],
        },
        {
          'models': [
            {'provider': 'A', 'available': true, 'latencyMs': 'bad'},
          ],
        },
        {
          'models': [
            {'provider': 'QWEN_OMNI_PLUS', 'available': true},
            {'provider': 'QWEN_OMNI_FLASH', 'available': true},
          ],
        },
      ]) {
        expect(
          () => ApiCallModelQualityRepository.readings(dto),
          throwsA(ApiFailure.invalidResponse),
        );
      }
    },
  );
  test(
    'refresh deduplicates fills missing and allows retry after failure',
    () async {
      final port = _Quality();
      final controller = CallModelQualityController(port);
      final refresh = controller.refresh(['QWEN_OMNI_FLASH', 'OTHER']);
      await controller.refresh(['QWEN_OMNI_PLUS']);
      expect(port.pending.length, 1);
      expect(controller.state.busy, isTrue);
      port.pending.single.complete({
        'QWEN_OMNI_PLUS': CallModelReading.probe(
          available: true,
          latencyMs: 100,
        ),
      });
      await refresh;
      expect(controller.state.readings['QWEN_OMNI_PLUS']!.latencyMs, 100);
      expect(
        controller.state.readings['OTHER']!.quality,
        CallModelQuality.unavailable,
      );
      final failure = controller.refresh(['QWEN_OMNI_PLUS']);
      port.pending.last.completeError(StateError('synthetic'));
      await failure;
      expect(controller.state.busy, isFalse);
      expect(controller.state.readings['QWEN_OMNI_PLUS']!.latencyMs, isNull);
      final retry = controller.refresh(['QWEN_OMNI_PLUS']);
      port.pending.last.complete({
        'QWEN_OMNI_PLUS': CallModelReading.probe(
          available: true,
          latencyMs: 200,
        ),
      });
      await retry;
      expect(controller.state.readings['QWEN_OMNI_PLUS']!.latencyMs, 200);
      controller.dispose();
    },
  );
  test('cancel reopen and disposal isolate late responses', () async {
    final port = _Quality();
    final controller = CallModelQualityController(port);
    final old = controller.refresh(['OLD']);
    controller.cancel();
    final newer = controller.refresh(['NEW']);
    port.pending.first.complete({
      'OLD': CallModelReading.probe(available: true, latencyMs: 1),
    });
    await old;
    expect(controller.state.busy, isTrue);
    expect(controller.state.readings, isEmpty);
    port.pending.last.complete({});
    await newer;
    expect(controller.state.readings.keys, ['NEW']);
    final last = controller.refresh(['NEW']);
    controller.dispose();
    port.pending.last.complete({});
    await last;
  });
}
