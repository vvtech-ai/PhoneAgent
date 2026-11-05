import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/presentation/controller/trusted_caller_controller.dart';

const owner = TrustedCallerOwner('synthetic-account', 'synthetic-phone', 1);

class FakePort implements TrustedCallerPort, TrustedCallerGuidePort {
  int guides = 0;
  Completer<void>? guidePending;
  bool failGuide = false;
  @override
  Future<void> markIntroductionSeen(TrustedCallerOwner owner) async {
    guides++;
    if (failGuide) throw const TrustedCallerFailure("SYNTHETIC_GUIDE");
    if (guidePending != null) await guidePending!.future;
  }

  int prepares = 0, reads = 0, opens = 0, releases = 0;
  bool available = true,
      failRead = false,
      failOpen = false,
      failRelease = false;
  Completer<bool>? preparation;
  Completer<TrustedCallerReport>? reportPending;
  Completer<void>? surface;
  TrustedCallerReport report = const TrustedCallerReport(
    owner: owner,
    status: TrustedCallerStatus.notAuthorized,
  );
  @override
  Future<bool> prepare(TrustedCallerOwner owner) async {
    prepares++;
    return preparation == null ? available : preparation!.future;
  }

  @override
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner) async {
    reads++;
    if (failRead) throw const TrustedCallerFailure('SYNTHETIC_READ_FAILURE');
    return reportPending == null ? report : reportPending!.future;
  }

  @override
  Future<void> openSettings(TrustedCallerOwner owner) async {
    opens++;
    if (failOpen) throw const TrustedCallerFailure('SYNTHETIC_OPEN_FAILURE');
    if (surface != null) await surface!.future;
  }

  @override
  Future<void> releaseSurface(TrustedCallerOwner owner) async {
    releases++;
    if (failRelease) throw const TrustedCallerFailure('SYNTHETIC_RELEASE');
  }
}

void main() {
  late FakePort port;
  late TrustedCallerOwner current;
  late TrustedCallerController controller;
  setUp(() {
    port = FakePort();
    current = owner;
    controller = TrustedCallerController(
      owner: owner,
      port: port,
      isCurrent: (captured) => captured.matches(current),
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });

  test('guide marker serializes reentry and preserves authorization', () async {
    port.report = const TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.notAuthorized,
      needsIntroduction: true,
    );
    await controller.refresh();
    port.guidePending = Completer<void>();
    final first = controller.markIntroductionSeen();
    expect(await controller.markIntroductionSeen(), false);
    expect(port.guides, 1);
    expect(controller.state.status, TrustedCallerStatus.notAuthorized);
    port.guidePending!.complete();
    expect(await first, true);
    expect(controller.state.needsIntroduction, false);
    expect(controller.state.status, TrustedCallerStatus.notAuthorized);
    expect(port.opens, 0);
  });

  test(
    'failed guide remains retryable without changing authorization',
    () async {
      port.report = const TrustedCallerReport(
        owner: owner,
        status: TrustedCallerStatus.notAuthorized,
        needsIntroduction: true,
      );
      await controller.refresh();
      port.failGuide = true;
      expect(await controller.markIntroductionSeen(), false);
      expect(controller.state.needsIntroduction, true);
      expect(controller.state.error, isNotEmpty);
      expect(controller.state.status, TrustedCallerStatus.notAuthorized);
      port.failGuide = false;
      expect(await controller.markIntroductionSeen(), true);
    },
  );

  test('late guide response cannot enter SDK after owner changes', () async {
    port.report = const TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.notAuthorized,
      needsIntroduction: true,
    );
    await controller.refresh();
    port.guidePending = Completer<void>();
    final marker = controller.markIntroductionSeen();
    current = const TrustedCallerOwner('other', 'other-phone', 2);
    port.guidePending!.complete();
    expect(await marker, false);
    await controller.openSettings();
    expect(port.opens, 0);
    expect(port.releases, 1);
    expect(controller.state.status, TrustedCallerStatus.unknown);
  });

  test('missing SDK refuses status and opening before device access', () async {
    port.available = false;
    await controller.openSettings();
    expect(port.prepares, 0);
    await controller.refresh();
    expect(controller.state.status, TrustedCallerStatus.unavailable);
    await controller.openSettings();
    expect(port.reads, 0);
    expect(port.opens, 0);
    expect(controller.state.busy, false);
  });

  test('duplicate and reentrant refresh share preparation', () async {
    port.preparation = Completer<bool>();
    final remove = controller.addListener((state) {
      if (state.busy) unawaited(controller.refresh());
    }, fireImmediately: false);
    final first = controller.refresh();
    final second = controller.refresh();
    expect(port.prepares, 1);
    port.preparation!.complete(true);
    await Future.wait([first, second]);
    remove();
    expect(port.reads, 1);
    expect(controller.state.status, TrustedCallerStatus.notAuthorized);
  });

  test('SDK presentation never optimistically marks authorization', () async {
    await controller.refresh();
    port.surface = Completer<void>();
    final opening = controller.openSettings();
    final duplicate = controller.openSettings();
    expect(port.opens, 1);
    expect(controller.state.status, TrustedCallerStatus.notAuthorized);
    expect(controller.state.busy, true);
    port.report = const TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.authorized,
      explicitSdkAuthorization: true,
    );
    port.surface!.complete();
    await Future.wait([opening, duplicate]);
    expect(port.reads, 2);
    expect(controller.state.status, TrustedCallerStatus.authorized);
  });

  test(
    'no explicit SDK proof and wrong report owners cannot authorize',
    () async {
      for (final report in [
        const TrustedCallerReport(
          owner: owner,
          status: TrustedCallerStatus.authorized,
        ),
        const TrustedCallerReport(
          owner: TrustedCallerOwner('other', 'synthetic-phone', 1),
          status: TrustedCallerStatus.authorized,
          explicitSdkAuthorization: true,
        ),
        const TrustedCallerReport(
          owner: TrustedCallerOwner('synthetic-account', 'other-phone', 1),
          status: TrustedCallerStatus.authorized,
          explicitSdkAuthorization: true,
        ),
        const TrustedCallerReport(
          owner: TrustedCallerOwner('synthetic-account', 'synthetic-phone', 2),
          status: TrustedCallerStatus.authorized,
          explicitSdkAuthorization: true,
        ),
      ]) {
        port.report = report;
        await controller.refresh();
        expect(controller.state.status, TrustedCallerStatus.unknown);
        expect(controller.state.error, isNotEmpty);
      }
    },
  );

  test(
    'account changes while preparing skip read and release surface',
    () async {
      port.preparation = Completer<bool>();
      final loading = controller.refresh();
      current = const TrustedCallerOwner('other', 'other-phone', 2);
      port.preparation!.complete(true);
      await loading;
      expect(port.reads, 0);
      expect(port.releases, 1);
      expect(controller.state.status, TrustedCallerStatus.unknown);
      await controller.refresh();
      expect(port.prepares, 1);
    },
  );

  test(
    'late explicit authorization is dropped after same-account relogin',
    () async {
      port.reportPending = Completer<TrustedCallerReport>();
      final loading = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(port.reads, 1);
      current = const TrustedCallerOwner(
        'synthetic-account',
        'synthetic-phone',
        2,
      );
      port.reportPending!.complete(
        const TrustedCallerReport(
          owner: owner,
          status: TrustedCallerStatus.authorized,
          explicitSdkAuthorization: true,
        ),
      );
      await loading;
      expect(controller.state.status, TrustedCallerStatus.unknown);
      expect(controller.state.busy, false);
    },
  );

  test('open failure is explicit and only user retry opens again', () async {
    await controller.refresh();
    port.failOpen = true;
    await controller.openSettings();
    expect(port.opens, 1);
    expect(port.reads, 1);
    expect(controller.state.error, isNotEmpty);
    expect(controller.state.status, TrustedCallerStatus.notAuthorized);
    port.failOpen = false;
    await controller.openSettings();
    expect(port.opens, 2);
    expect(port.reads, 2);
  });

  test('read failure can retry without automatic SDK presentation', () async {
    port.failRead = true;
    await controller.refresh();
    expect(controller.state.status, TrustedCallerStatus.unknown);
    port.failRead = false;
    port.report = const TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.readyToConfigure,
    );
    await controller.refresh();
    expect(controller.state.status, TrustedCallerStatus.readyToConfigure);
    expect(port.opens, 0);
  });

  test(
    'SDK return read failure clears previously confirmed authorization',
    () async {
      port.report = const TrustedCallerReport(
        owner: owner,
        status: TrustedCallerStatus.authorized,
        explicitSdkAuthorization: true,
      );
      await controller.refresh();
      port.failRead = true;
      await controller.openSettings();
      expect(controller.state.status, TrustedCallerStatus.unknown);
      expect(controller.state.error, isNotEmpty);
    },
  );

  test('disposed pending preparation does not read or open', () async {
    port.preparation = Completer<bool>();
    final pending = controller.refresh();
    controller.dispose();
    port.preparation!.complete(true);
    await pending;
    expect(port.reads, 0);
    expect(port.opens, 0);
    expect(port.releases, 1);
  });

  test(
    'disposed preparation and SDK return have no downstream actions',
    () async {
      await controller.refresh();
      port.surface = Completer<void>();
      final opening = controller.openSettings();
      controller.dispose();
      port.surface!.complete();
      await opening;
      expect(port.reads, 1);
      expect(port.releases, 1);
    },
  );

  test('release failure is reported without owner identifiers', () async {
    controller.dispose();
    port.failRelease = true;
    final codes = <String>[];
    controller = TrustedCallerController(
      owner: owner,
      port: port,
      isCurrent: (_) => true,
      onCleanupFailure: codes.add,
    );
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(codes, ['TRUSTED_CALLER_SURFACE_RELEASE_UNCONFIRMED']);
    expect(codes.single, isNot(contains(owner.accountId)));
  });
}
