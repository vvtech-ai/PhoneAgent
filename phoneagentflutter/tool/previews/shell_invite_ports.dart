import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/features/invite/domain/invite_device.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';

/// No system links, clipboard, files or account storage in the MOCK shell.
class ShellInviteDevice implements InviteDevice {
  const ShellInviteDevice();
  static Uint8List? lastPoster;
  @override
  Future<void> copy(String text) async {}
  @override
  Future<bool> savePoster(Uint8List png) async {
    lastPoster = Uint8List.fromList(
      png,
    ); // Debug capture in memory; never writes the user's gallery.
    return false;
  }

  @override
  Future<String?> initialLink() async => null;
  @override
  Stream<String> get links => const Stream.empty();
}

List<Override> shellInviteOverrides() => [
  inviteStoreProvider.overrideWith((ref) => MemoryInviteStore()),
  inviteDeviceProvider.overrideWithValue(const ShellInviteDevice()),
  inviteRepositoryProvider.overrideWithValue(const ShellInviteRepository()),
];

/// Synthetic activity; all invitation reads and events stay in memory.
class ShellInviteRepository implements InviteRepository {
  const ShellInviteRepository();
  static const overview = InviteOverview(
    InviteActivity(
      id: 'synthetic-ui-invite',
      name: '合成邀请活动',
      subtitle: '邀请好友注册 PhoneAgent，双方领取活动积分',
      rules: '1. 仅限新用户。\n2. 积分以实际到账为准。',
      inviterPoints: 100,
      inviteePoints: 50,
      quota: 8,
      longTerm: true,
      bonusEnabled: true,
      bonusThreshold: 8,
      bonusPoints: 500,
    ),
    InvitePersonal(true, 2, 100, 500, false),
  );
  @override
  Future<InviteOverview> activity() async => overview;
  @override
  Future<InviteCode> code() async => const InviteCode(
    'ABCD',
    'https://example.test/invite/?code=ABCD',
    '2035-01-01T00:00:00Z',
    2,
    1,
    5,
    overview,
  );
  @override
  Future<InviteRecords> records([String? cursor]) async => const InviteRecords(
    [
      InviteRecord('synthetic-ui-invite-1', '13800000000', '2026-10-06', 100),
      InviteRecord('synthetic-ui-invite-2', '13900000000', '2026-10-06', 100),
    ],
    2,
    null,
  );
  @override
  Future<void> event(String period, String type, String eventId) async {}
}
