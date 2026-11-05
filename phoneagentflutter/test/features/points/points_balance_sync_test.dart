import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';

PointsAccount _account(int balance) => PointsAccount(
  totalBalance: balance + 5,
  availableBalance: balance,
  heldBalance: 5,
  updatedAt: 'synthetic-$balance',
);
const _ledger = PointsLedgerPage(
  items: [],
  page: 0,
  size: 20,
  totalElements: 0,
  totalPages: 0,
);

class _Repository implements PointsWalletRepository {
  int accounts = 0, ledgers = 0, balance = 100;
  Completer<PointsAccount>? accountGate;
  Completer<PointsLedgerPage>? ledgerGate;
  Object? failure;
  @override
  Future<PointsAccount> account() async {
    accounts++;
    if (failure != null) throw failure!;
    return accountGate?.future ?? _account(balance);
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async {
    ledgers++;
    return ledgerGate?.future ?? _ledger;
  }
}

void main() {
  test(
    'independent balance updates shared state, not fictitious ledger',
    () async {
      final repo = _Repository();
      final c = PointsWalletController(repo);
      addTearDown(c.dispose);
      await c.refresh();
      repo.balance = 250;
      expect(await c.refreshBalance(), 250);
      expect(c.state.account!.availableBalance, 250);
      expect(c.state.account!.totalBalance, 255);
      expect(c.state.admissionBalance, 250);
      expect(c.state.stale, isFalse);
      expect(c.state.ledgerStale, isTrue);
      expect(repo.ledgers, 1);
      await c.refresh();
      expect(c.state.ledgerStale, isFalse);
    },
  );
  test('independent balance calls share one pending request', () async {
    final repo = _Repository()..accountGate = Completer<PointsAccount>();
    final c = PointsWalletController(repo);
    addTearDown(c.dispose);
    final first = c.refreshBalance(), second = c.refreshBalance();
    expect(identical(first, second), isTrue);
    expect(repo.accounts, 1);
    repo.accountGate!.complete(_account(50));
    expect(await first, 50);
    expect(await second, 50);
    expect(repo.ledgers, 0);
  });
  test('wallet refresh and admission share account IO', () async {
    final repo = _Repository()..accountGate = Completer<PointsAccount>();
    final c = PointsWalletController(repo);
    addTearDown(c.dispose);
    final full = c.refresh(), balance = c.refreshBalance();
    expect(repo.accounts, 1);
    repo.accountGate!.complete(_account(60));
    await full;
    expect(await balance, 60);
    expect(c.state.account!.availableBalance, 60);
    expect(repo.ledgers, 1);
  });
  for (final ledgerFails in [false, true]) {
    test(
      'old full refresh cannot overwrite newer balance; ledgerFails=$ledgerFails',
      () async {
        final repo = _Repository()..ledgerGate = Completer<PointsLedgerPage>();
        final c = PointsWalletController(repo);
        addTearDown(c.dispose);
        final full = c.refresh();
        await Future<void>.delayed(Duration.zero);
        repo.balance = 300;
        await c.refreshBalance();
        if (ledgerFails) {
          repo.ledgerGate!.completeError(
            StateError('synthetic ledger failure'),
          );
        } else {
          repo.ledgerGate!.complete(_ledger);
        }
        await full;
        expect(c.state.account!.availableBalance, 300);
        expect(c.state.admissionBalance, 300);
        expect(c.state.stale, isFalse);
        expect(c.state.ledgerStale, isTrue);
      },
    );
  }
  for (final error in [
    ApiFailure.network,
    ApiFailure.sessionChanged,
    ApiFailure.signedOut,
  ]) {
    test(
      'balance error $error preserves display but not admission authority',
      () async {
        final repo = _Repository();
        final c = PointsWalletController(repo);
        addTearDown(c.dispose);
        await c.refresh();
        repo.failure = error;
        await expectLater(c.refreshBalance(), throwsA(error));
        expect(c.state.account!.availableBalance, 100);
        expect(c.state.admissionBalance, isNull);
        expect(c.state.stale, isTrue);
        repo.failure = null;
        repo.balance = 200;
        expect(await c.refreshBalance(), 200);
        expect(c.state.admissionBalance, 200);
      },
    );
  }
  test('old full response cannot clear more recent balance failure', () async {
    final repo = _Repository()..ledgerGate = Completer<PointsLedgerPage>();
    final c = PointsWalletController(repo);
    addTearDown(c.dispose);
    final full = c.refresh();
    await Future<void>.delayed(Duration.zero);
    repo.failure = ApiFailure.network;
    await expectLater(c.refreshBalance(), throwsA(ApiFailure.network));
    repo.ledgerGate!.complete(_ledger);
    await full;
    expect(c.state.admissionBalance, isNull);
    expect(c.state.stale, isTrue);
  });
  test(
    'disposed refresh never publishes or returns execution authority',
    () async {
      final repo = _Repository()..accountGate = Completer<PointsAccount>();
      final c = PointsWalletController(repo);
      final pending = c.refreshBalance();
      final expectation = expectLater(pending, throwsStateError);
      c.dispose();
      repo.accountGate!.complete(_account(200));
      await expectation;
      await expectLater(c.refreshBalance(), throwsStateError);
      expect(repo.accounts, 1);
    },
  );
}
