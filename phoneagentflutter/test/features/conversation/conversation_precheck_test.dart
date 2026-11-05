import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_precheck_controller.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';

class Network implements NetworkAvailabilitySource, NetworkAvailabilityEvents {
  final readResult = Completer<NetworkAvailability>();
  final changes = StreamController<NetworkAvailability>.broadcast(sync: true);
  @override
  Future<NetworkAvailability> read() => readResult.future;
  @override
  Stream<NetworkAvailability> watch() => changes.stream;
}

void main() {
  test('original sequence waits for real model then clears after 500ms', () {
    fakeAsync((time) {
      final network = Network();
      final check = ConversationPrecheckController(network, network);
      expect(check.label, '正在检查网络连接');
      network.readResult.complete(NetworkAvailability.available);
      time.flushMicrotasks();
      time.elapse(const Duration(milliseconds: 300));
      expect(check.label, '正在连接大模型服务');
      time.elapse(const Duration(seconds: 2));
      expect(check.label, '正在连接大模型服务');
      check.model(ready: true, blocked: false);
      expect(check.label, '正在检查外呼通道');
      time.elapse(const Duration(milliseconds: 349));
      expect(check.label, '正在检查外呼通道');
      time.elapse(const Duration(milliseconds: 1));
      expect(check.label, '任务执行环境检测通过');
      time.elapse(const Duration(milliseconds: 499));
      expect(check.label, '任务执行环境检测通过');
      time.elapse(const Duration(milliseconds: 1));
      expect(check.label, isEmpty);
      check.dispose();
      network.changes.close();
    });
  });
  test(
    'offline and model failure never pass; newer network event wins over read',
    () {
      fakeAsync((time) {
        final network = Network();
        final check = ConversationPrecheckController(network, network);
        check.model(ready: true, blocked: false);
        network.changes.add(NetworkAvailability.unavailable);
        network.readResult.complete(NetworkAvailability.available);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 5));
        expect(check.blocked, isTrue);
        expect(check.label, '网络连接不可用');
        network.changes.add(NetworkAvailability.available);
        check.model(ready: false, blocked: true);
        time.elapse(const Duration(seconds: 5));
        expect(check.label, '大模型服务不可用');
        check.model(ready: true, blocked: false);
        time.elapse(const Duration(seconds: 2));
        expect(check.label, isEmpty);
        check.dispose();
        network.changes.close();
      });
    },
  );
  test(
    'owner disposal releases subscription and rejects read and model callbacks',
    () {
      fakeAsync((time) {
        final network = Network();
        final check = ConversationPrecheckController(network, network);
        var changes = 0;
        check.addListener(() => changes++);
        check.dispose();
        network.readResult.complete(NetworkAvailability.available);
        network.changes.add(NetworkAvailability.available);
        check.model(ready: true, blocked: false);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 5));
        expect(changes, 0);
        expect(network.changes.hasListener, isFalse);
        network.changes.close();
      });
    },
  );
}
