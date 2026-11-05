import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/trusted_caller/data/trusted_incoming_diagnostics.dart';

void main() {
  Map<String, Object> failure({
    Object domain = 'NSCocoaErrorDomain',
    Object code = 3000,
  }) => {
    'diagnostic': {
      'stage': 'pushRegistration',
      'code': 'IOS_APNS_REGISTRATION_FAILED',
      'result': 'failed',
      'timeMs': 1700000000000,
      'errorDomain': domain,
      'errorCode': code,
      'localizedDescription': 'synthetic-private',
      'userInfo': {'token': 'synthetic-private'},
    },
  };

  test('registration chain stages survive export without private metadata', () {
    final stages = {
      'pushRegistration': [
        'IOS_APNS_CONFIG_MISSING',
        'IOS_APNS_CONFIG_MISMATCH',
        'IOS_APNS_REGISTER_REQUESTED',
        'IOS_APNS_REGISTER_RETURNED',
        'IOS_APNS_CALLBACK_PENDING',
        'IOS_APNS_TOKEN_CALLBACK',
        'IOS_APNS_TOKEN_REJECTED',
      ],
      'pushBinding': [
        'IOS_BIND_STATE_CONFIRMED',
        'IOS_BIND_STATE_PENDING',
        'IOS_BIND_STATE_UNCERTAIN',
        'IOS_BIND_STATE_UNCONFIRMED',
        'IOS_BIND_STATE_INIT_FAILED',
        'IOS_BIND_STATE_INITIALIZING',
        'IOS_BIND_WAIT_OWNER',
        'IOS_BIND_WAIT_PERMISSION',
        'IOS_BIND_WAIT_TOKEN',
        'IOS_SDK_INIT_STARTED',
        'IOS_SDK_INIT_SUCCEEDED',
        'IOS_SDK_INIT_FAILED',
        'IOS_BIND_WAIT_RETRY',
      ],
    };
    final events = <DiagnosticEvent>[];
    final trace = TrustedIncomingDiagnostics(events.add, 'test');
    for (final entry in stages.entries) {
      for (final code in entry.value) {
        final value = failure();
        (value['diagnostic']! as Map<String, Object>).addAll({
          'stage': entry.key,
          'code': code,
          'result': 'received',
        });
        expect(trace.consume(value), true);
        final json = DiagnosticEvent.fromJson(events.last.toJson()).toJson();
        expect(events.last.trustedCaller!.code, code);
        expect(json.toString(), contains(code));
        expect(json.toString(), isNot(contains('synthetic-private')));
        expect(
          events.last.trustedCaller!.toJson().containsKey('errorCode'),
          false,
        );
      }
    }
    expect(events, hasLength(20));
  });

  test('APNs failure preserves safe system domain and code through export', () {
    final events = <DiagnosticEvent>[];
    final trace = TrustedIncomingDiagnostics(events.add, 'test');
    expect(trace.consume(failure()), true);
    final json = events.single.toJson();
    final restored = DiagnosticEvent.fromJson(json).trustedCaller!.toJson();
    expect(restored['errorDomain'], 'NSCocoaErrorDomain');
    expect(restored['errorCode'], 3000);
    expect(events.single.result, DiagnosticResult.failed);
    expect(json.toString(), isNot(contains('synthetic-private')));
  });

  test('domain and code are bounded independently without losing failure', () {
    final events = <DiagnosticEvent>[];
    final trace = TrustedIncomingDiagnostics(events.add, 'test');
    for (final code in [-1009, -2147483648, 2147483647]) {
      trace.consume(failure(domain: 'NSURLErrorDomain', code: code));
      expect(events.last.trustedCaller!.toJson()['errorCode'], code);
    }
    for (final code in [
      true,
      'synthetic-private',
      3000.0,
      2147483648,
      -2147483649,
    ]) {
      trace.consume(failure(domain: 'synthetic-private', code: code));
      final json = events.last.trustedCaller!.toJson();
      expect(json['errorDomain'], 'other');
      expect(json.containsKey('errorCode'), false);
      expect(json.toString(), isNot(contains('synthetic-private')));
    }
    expect(events, hasLength(8));
  });

  test(
    'foreign stages and nonfailure events cannot export APNs error fields',
    () {
      final events = <DiagnosticEvent>[];
      final trace = TrustedIncomingDiagnostics(events.add, 'test');
      for (final overrides in [
        {'stage': 'pushBinding', 'code': 'IOS_BIND_FAILED'},
        {'code': 'IOS_APNS_ALLOWED', 'result': 'succeeded'},
        {'result': 'succeeded'},
      ]) {
        final value = failure();
        final raw = value['diagnostic']! as Map<String, Object>;
        raw.addAll(overrides);
        trace.consume(value);
        expect(
          events.last.trustedCaller!.toJson().containsKey('errorDomain'),
          false,
        );
        expect(
          events.last.trustedCaller!.toJson().containsKey('errorCode'),
          false,
        );
      }
    },
  );

  test('direct persisted diagnostics are sanitized on roundtrip', () {
    final details = DiagnosticTrustedCallerDetails.fromJson({
      'stage': 'pushRegistration',
      'platform': 'ios',
      'environment': 'test',
      'code': 'IOS_APNS_REGISTRATION_FAILED',
      'errorDomain': 'synthetic-private',
      'errorCode': true,
      'message': 'synthetic-private',
    });
    expect(details.toJson()['errorDomain'], 'other');
    expect(details.toJson().containsKey('errorCode'), false);
    expect(details.toJson().toString(), isNot(contains('synthetic-private')));
    for (final platform in ['android', 'other']) {
      final foreign = DiagnosticTrustedCallerDetails.fromJson({
        ...details.toJson(),
        'platform': platform,
        'errorCode': 3000,
      });
      expect(foreign.toJson().containsKey('errorDomain'), false);
      expect(foreign.toJson().containsKey('errorCode'), false);
    }
  });
}
