import 'package:phone_agent/features/points/domain/points_activation.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';

/// Fixed synthetic balance, not a local replacement for backend accounting.
class ShellPreviewPoints
    implements PointsActivationRepository, PointsWalletRepository {
  static const snapshot = PointsAccount(
    totalBalance: 900,
    availableBalance: 900,
    heldBalance: 0,
    updatedAt: '2026-09-20T00:00:00Z',
    todayDailyGrantReceived: true,
    todayDailyGrantPoints: 100,
  );

  @override
  Future<PointsActivation> activate() async =>
      const PointsActivation(snapshot, []);

  @override
  Future<PointsAccount> account() async => snapshot;

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      PointsLedgerPage(
        page: page,
        size: size,
        totalElements: 1,
        totalPages: 1,
        items: page == 0
            ? const [
                PointsLedgerItem(
                  id: 1,
                  type: 'DAILY_LOGIN_GRANT',
                  title: '合成登录赠送',
                  delta: 100,
                  balanceAfter: 900,
                  description: 'MOCK，仅演练样例',
                  occurredAt: '2026-09-20T00:00:00Z',
                ),
              ]
            : const [],
      );
}

class ShellPreviewAudioStore implements OriginalAudioStore {
  OriginalAudioSettings value = const OriginalAudioSettings();
  @override
  Future<OriginalAudioSettings> read() async => value;
  @override
  Future<void> write(OriginalAudioSettings value) async => this.value = value;
}
