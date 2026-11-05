import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/settings/data/api_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/domain/outbound_number.dart';
import 'package:phone_agent/features/settings/presentation/controller/outbound_number_controller.dart';
import '../../support/synthetic_account_api.dart';

class DelayedOutbound extends PreviewOutboundNumberRepository {
  final gate = Completer<OutboundNumber>();
  @override
  Future<OutboundNumber> save(String number) {
    saves++;
    return gate.future;
  }
}

void main() {
  test(
    'nested preview scopes never reuse an already loaded parent controller',
    () async {
      final real = PreviewOutboundNumberRepository(number: '2025550123');
      final mock = PreviewOutboundNumberRepository(number: '2025550124');
      final parent = ProviderContainer(
        overrides: [outboundNumberRepositoryProvider.overrideWithValue(real)],
      );
      addTearDown(parent.dispose);
      final parentSub = parent.listen(outboundNumberProvider, (_, _) {});
      addTearDown(parentSub.close);
      await Future<void>.delayed(Duration.zero);
      final child = ProviderContainer(
        parent: parent,
        overrides: [outboundNumberRepositoryProvider.overrideWithValue(mock)],
      );
      addTearDown(child.dispose);
      final childSub = child.listen(outboundNumberProvider, (_, _) {});
      addTearDown(childSub.close);
      await Future<void>.delayed(Duration.zero);
      expect(child.read(outboundNumberProvider).saved!.number, '2025550124');
      final childController = child.read(outboundNumberProvider.notifier);
      childController.edit('2025550125');
      await childController.save();
      expect(real.saves, 0);
      expect(parent.read(outboundNumberProvider).saved!.number, '2025550123');
      expect(mock.value.number, '2025550125');
    },
  );
  test('v65 outbound normalization is not ordinary dialing validation', () {
    const cases = {
      '＋８６ （１３８）００１３—８０００': '13800138000',
      '+86 755-5550123': '07555550123',
      '0086-0755-5550123': '07555550123',
      '0086 138 0013 8000': '13800138000',
      '+1 (202) 555-0123': '+12025550123',
      '0012025550123': '0012025550123',
      '8613800138000': '8613800138000',
      '12345678901234567': '12345678901234567',
      '12': '12',
      '+86': '',
      'words': '',
      '(+1)202': '1202',
      '0755#123': '0755123',
    };
    for (final entry in cases.entries) {
      expect(
        normalizeOutboundNumber(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      const OutboundNumber('+8613800138000', configured: true).masked,
      '138****8000',
    );
    expect(
      const OutboundNumber('+12025550123', configured: true).masked,
      '+12025550123',
    );
  });
  test(
    'load caches and force reload uses authoritative configured value',
    () async {
      final repository = PreviewOutboundNumberRepository(number: '2025550123');
      final controller = OutboundNumberController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.load();
      expect(repository.reads, 1);
      controller.edit('new unsaved draft');
      controller.discardDraft();
      expect(controller.snapshot.draft, '2025550123');
      repository.value = const OutboundNumber('2025550124', configured: false);
      await controller.load(force: true);
      expect(controller.snapshot.saved!.configured, isFalse);
      expect(controller.snapshot.draft, '2025550124');
    },
  );
  test('save/delete success and blank guard do not call a dialer', () async {
    final repository = PreviewOutboundNumberRepository();
    final controller = OutboundNumberController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    expect(await controller.save(), isFalse);
    expect(repository.saves, 0);
    controller.edit('＋１ （２０２）５５５－０１２３');
    expect(await controller.save(), isTrue);
    expect(controller.snapshot.draft, '+12025550123');
    expect(await controller.delete(), isTrue);
    expect(controller.snapshot.saved!.configured, isFalse);
    expect(await controller.delete(), isFalse);
    expect(repository.deletes, 1);
  });
  test(
    'read/write failures preserve draft and never retry automatically',
    () async {
      final repository = PreviewOutboundNumberRepository()..failRead = true;
      final controller = OutboundNumberController(repository);
      addTearDown(controller.dispose);
      expect(await controller.load(), isFalse);
      expect(controller.snapshot.saved, isNull);
      controller.discardDraft();
      expect(controller.snapshot.error, contains('加载失败'));
      repository.failRead = false;
      await controller.load();
      controller.edit('202-555-0123');
      repository.failWrite = true;
      expect(await controller.save(), isFalse);
      expect(controller.snapshot.draft, '202-555-0123');
      expect(repository.saves, 1);
      repository.failWrite = false;
      await controller.save();
      repository.failWrite = true;
      expect(await controller.delete(), isFalse);
      expect(controller.snapshot.saved!.number, '2025550123');
      expect(repository.deletes, 1);
    },
  );
  test('pending write excludes edit/read/delete/duplicate save', () async {
    final repository = DelayedOutbound();
    final controller = OutboundNumberController(repository);
    addTearDown(controller.dispose);
    controller.edit('2025550123');
    final pending = controller.save();
    controller.edit('2025550124');
    expect(await controller.save(), isFalse);
    expect(await controller.load(force: true), isFalse);
    expect(await controller.delete(), isFalse);
    repository.gate.complete(
      const OutboundNumber('2025550123', configured: true),
    );
    expect(await pending, isTrue);
    expect(repository.saves, 1);
    expect(controller.snapshot.draft, '2025550123');
  });
  test(
    'disposed account scope ignores late write without success effect',
    () async {
      final repository = DelayedOutbound();
      final controller = OutboundNumberController(repository)
        ..edit('2025550123');
      final pending = controller.save();
      controller.dispose();
      repository.gate.complete(
        const OutboundNumber('2025550123', configured: true),
      );
      expect(await pending, isFalse);
      expect(await controller.save(), isFalse);
      expect(repository.saves, 1);
    },
  );
  test(
    'GET POST DELETE match authenticated account headers and body',
    () async {
      final fixture = SyntheticAccountApi();
      addTearDown(fixture.api.close);
      fixture.data = {
        'accountId': 'a',
        'outboundNumber': '2025550123',
        'configured': true,
      };
      final repository = ApiOutboundNumberRepository(fixture.api, 'a');
      expect((await repository.load()).number, '2025550123');
      await repository.save('2025550123');
      fixture.data = {
        'accountId': 'a',
        'outboundNumber': '',
        'configured': false,
      };
      expect((await repository.delete()).configured, isFalse);
      expect(fixture.requests.map((r) => r.method), ['GET', 'POST', 'DELETE']);
      expect(fixture.requests[1].data, {'outboundNumber': '2025550123'});
      for (final request in fixture.requests) {
        expect(request.path, endsWith('/api/account/settings/outbound-number'));
        expect(request.headers['X-Account-Id'], 'a');
        expect(request.headers['Authorization'], 'Bearer synthetic');
      }
    },
  );
  test('wrong-account and malformed responses never become settings', () async {
    final fixture = SyntheticAccountApi();
    addTearDown(fixture.api.close);
    final repository = ApiOutboundNumberRepository(fixture.api, 'a');
    fixture.data = {
      'accountId': 'b',
      'outboundNumber': '',
      'configured': false,
    };
    await expectLater(repository.load(), throwsA(ApiFailure.sessionChanged));
    fixture.data = {
      'accountId': 'a',
      'outboundNumber': 12,
      'configured': false,
    };
    await expectLater(repository.load(), throwsA(ApiFailure.invalidResponse));
  });
  test('server error and expired owner never replay writes', () async {
    final fixture = SyntheticAccountApi()..status = 500;
    addTearDown(fixture.api.close);
    final repository = ApiOutboundNumberRepository(fixture.api, 'a');
    await expectLater(
      repository.save('2025550123'),
      throwsA(ApiFailure.rejected),
    );
    expect(fixture.requests.length, 1);
    fixture.credentials = const AccountCredentials('b', 'synthetic', 2);
    await expectLater(repository.delete(), throwsA(ApiFailure.sessionChanged));
    expect(fixture.requests.length, 1);
  });
}
