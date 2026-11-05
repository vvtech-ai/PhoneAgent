import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/domain/identity_deletion_cleanup.dart';
import 'package:phone_agent/features/identity/presentation/controller/identity_controller.dart';

void main() {
  test(
    'delete effects run once after server success and keep operation locked',
    () async {
      final repo = _Repository();
      final effect = Completer<void>();
      var effects = 0;
      final c = IdentityController(
        repo,
        createDeletionCleanup: () => cleanup(() async {
          effects++;
          await effect.future;
        }),
      );
      addTearDown(c.dispose);
      await c.load();
      repo.gate = Completer<IdentityProfile>();
      final pending = c.delete(confirmed: true);
      expect(effects, 0);
      repo.gate!.complete(const IdentityProfile(accountId: 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(effects, 1);
      expect(c.state.busy, isTrue);
      expect(await c.delete(confirmed: true), IdentityOutcome.rejected);
      effect.complete();
      expect(await pending, IdentityOutcome.deleted);
      expect(c.state.busy, isFalse);
      expect(repo.deletes, 1);
    },
  );

  test('local failure never reclassifies successful server deletion', () async {
    final repo = _Repository()
      ..value = const IdentityProfile(accountId: 'a', name: '旧资料');
    final c = IdentityController(
      repo,
      createDeletionCleanup: () => cleanup(() async {
        throw StateError('synthetic storage failure');
      }),
    );
    addTearDown(c.dispose);
    await c.load();
    expect(await c.delete(confirmed: true), IdentityOutcome.deleted);
    expect(c.state.profile!.status, IdentityStatus.empty);
    expect(c.state.error, '身份已删除，但本地录音清理或引导状态保存失败');
    expect(repo.deletes, 1);
  });

  test(
    'failed deletion and disposed account never invoke deletion effects',
    () async {
      var effects = 0;
      final repo = _Repository();
      final c = IdentityController(
        repo,
        createDeletionCleanup: () => cleanup(() async {
          effects++;
        }),
      );
      await c.load();
      repo.fail = true;
      expect(await c.delete(confirmed: true), IdentityOutcome.rejected);
      expect(effects, 0);
      repo.fail = false;
      repo.gate = Completer<IdentityProfile>();
      final pending = c.delete(confirmed: true);
      c.dispose();
      repo.gate!.complete(const IdentityProfile(accountId: 'a'));
      expect(await pending, IdentityOutcome.rejected);
      expect(effects, 0);
    },
  );

  test(
    'dispose while local effects pending does not update disposed state',
    () async {
      final effect = Completer<void>();
      final c = IdentityController(
        _Repository(),
        createDeletionCleanup: () => cleanup(() => effect.future),
      );
      await c.load();
      final pending = c.delete(confirmed: true);
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      effect.complete();
      expect(await pending, IdentityOutcome.rejected);
    },
  );

  test('status is empty without name, verification requires server flag', () {
    expect(
      const IdentityProfile(
        accountId: 'a',
        verificationStatus: 'VERIFIED',
      ).status,
      IdentityStatus.empty,
    );
    expect(
      const IdentityProfile(accountId: 'a', name: '名字').status,
      IdentityStatus.filled,
    );
    expect(
      const IdentityProfile(
        accountId: 'a',
        name: '名字',
        verificationStatus: ' verified ',
      ).status,
      IdentityStatus.verified,
    );
  });
  test(
    'normal draft trims phone input, limits name and validates optional mainland phone',
    () {
      final draft = const IdentityDraft().edit(
        name: '名' * 150,
        phone: '138 0000 000012',
      );
      expect(draft.name.length, 128);
      expect(draft.contactPhone, '13800000000');
      expect(draft.validation, isNull);
      expect(const IdentityDraft(name: '名字').validation, isNull);
      expect(
        const IdentityDraft(name: '名字', contactPhone: '123').validation,
        IdentityValidation.invalidPhone,
      );
    },
  );
  test(
    'verified name locked; only metadata save; failed save preserves draft',
    () async {
      final repo = _Repository()
        ..value = const IdentityProfile(
          accountId: 'a',
          name: '认证姓名',
          verificationStatus: 'VERIFIED',
        );
      final controller = IdentityController(repo);
      addTearDown(controller.dispose);
      await controller.load();
      controller.beginEdit();
      controller.edit(name: '不能更改', gender: '男', phone: '13800000000');
      expect(controller.state.draft.name, '认证姓名');
      repo.fail = true;
      expect(await controller.save(), IdentityOutcome.rejected);
      expect(controller.state.editing, isTrue);
      expect(controller.state.draft.gender, '男');
      expect(controller.state.profile!.name, '认证姓名');
      repo.fail = false;
      expect(await controller.save(), IdentityOutcome.savedReturn);
      expect(repo.verified, isTrue);
    },
  );
  test('first fill stays; no write while unloaded or invalid', () async {
    final repo = _Repository();
    final c = IdentityController(repo);
    addTearDown(c.dispose);
    expect(await c.save(), IdentityOutcome.rejected);
    await c.load();
    c.beginEdit();
    expect(await c.save(), IdentityOutcome.rejected);
    expect(repo.writes, 0);
    c.edit(name: '新名字');
    expect(await c.save(), IdentityOutcome.savedStay);
    expect(repo.verified, isFalse);
  });
  test(
    'delete confirmation and operation single flight; no late write after dispose',
    () async {
      final repo = _Repository()
        ..value = const IdentityProfile(accountId: 'a', name: '名字');
      final c = IdentityController(repo);
      await c.load();
      expect(await c.delete(confirmed: false), IdentityOutcome.rejected);
      expect(repo.deletes, 0);
      repo.gate = Completer<IdentityProfile>();
      final pending = c.delete(confirmed: true);
      expect(await c.delete(confirmed: true), IdentityOutcome.rejected);
      expect(repo.deletes, 1);
      c.dispose();
      repo.gate!.complete(const IdentityProfile(accountId: 'a'));
      expect(await pending, IdentityOutcome.rejected);
    },
  );
  test('delete failure retains profile and allows retry', () async {
    final repo = _Repository()
      ..value = const IdentityProfile(accountId: 'a', name: '名字');
    final c = IdentityController(repo);
    addTearDown(c.dispose);
    await c.load();
    repo.fail = true;
    expect(await c.delete(confirmed: true), IdentityOutcome.rejected);
    expect(c.state.profile!.name, '名字');
    repo.fail = false;
    expect(await c.delete(confirmed: true), IdentityOutcome.deleted);
    expect(c.state.profile!.status, IdentityStatus.empty);
  });
}

IdentityDeletionCleanup cleanup(Future<void> Function() effect) =>
    IdentityDeletionCleanup(markSkipped: effect, clearRecording: () async {});

class _Repository implements IdentityRepository {
  IdentityProfile value = const IdentityProfile(accountId: 'a');
  bool fail = false, verified = false;
  int writes = 0, deletes = 0;
  Completer<IdentityProfile>? gate;
  @override
  Future<IdentityProfile> load() async => value;
  @override
  Future<IdentityProfile> save(
    IdentityDraft draft, {
    required bool verified,
  }) async {
    writes++;
    this.verified = verified;
    if (fail) throw StateError('synthetic');
    return IdentityProfile(
      accountId: 'a',
      name: draft.name,
      gender: draft.gender,
    );
  }

  @override
  Future<IdentityProfile> delete() async {
    deletes++;
    if (fail) throw StateError('synthetic');
    return gate == null
        ? const IdentityProfile(accountId: 'a')
        : await gate!.future;
  }
}
