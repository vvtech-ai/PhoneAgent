import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_system_dial_target.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contact_system_dial_controller.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';

class _Dialer implements SystemDialer {
  final calls = <String>[];
  final pending = Completer<SystemDialResult>();

  @override
  Future<SystemDialResult> open(String number) {
    calls.add(number);
    return pending.future;
  }
}

void main() {
  test('native system target preserves country prefix and dial characters', () {
    expect(contactSystemDialTarget(' +1 (202) 555-0101 '), '+12025550101');
    expect(contactSystemDialTarget('0086 010-1234'), '00860101234');
    expect(contactSystemDialTarget('123-45#6*'), '12345#6*');
    expect(contactSystemDialTarget('未设置'), '');
  });

  test(
    'handoff prevents duplicate request without claiming connection',
    () async {
      final port = _Dialer();
      final controller = ContactSystemDialController(port);
      addTearDown(controller.dispose);
      final result = controller.open('+1 (202) 555-0101');
      expect(controller.state, isTrue);
      expect(await controller.open('different'), isNull);
      port.pending.complete(SystemDialResult.opened);
      expect(await result, '');
      expect(controller.state, isFalse);
      expect(port.calls, ['+12025550101']);
    },
  );

  test('disposed account owner ignores late system failure', () async {
    final port = _Dialer();
    final controller = ContactSystemDialController(port);
    final result = controller.open('12345');
    controller.dispose();
    port.pending.complete(SystemDialResult.failed);
    expect(await result, isNull);
  });

  test('invalid contact never invokes OS', () async {
    final port = _Dialer();
    final controller = ContactSystemDialController(port);
    addTearDown(controller.dispose);
    expect(await controller.open('无号码'), '联系人号码格式不正确');
    expect(port.calls, isEmpty);
  });

  for (final result in [
    SystemDialResult.failed,
    SystemDialResult.unsupported,
  ]) {
    test('OS $result remains a retryable failure', () async {
      final port = _Dialer();
      final controller = ContactSystemDialController(port);
      addTearDown(controller.dispose);
      final operation = controller.open('12345');
      port.pending.complete(result);
      expect(await operation, isNotEmpty);
      expect(controller.state, isFalse);
    });
  }
}
