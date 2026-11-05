import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_device.dart';

const sampleActivity = InviteActivity(
  id: 'p1',
  name: '邀请好友，一起体验',
  rules: '仅限新用户，积分以到账为准。',
  inviterPoints: 10,
  inviteePoints: 20,
  quota: 5,
);
const sampleCode = InviteCode(
  'ABCD',
  'https://example.test/invite/?code=ABCD',
  '2035-01-01T00:00:00Z',
  1,
  0,
  4,
  InviteOverview(sampleActivity, null),
);

class FakeInviteRepository implements InviteRepository {
  bool fail = false, failEvent = false;
  int recordCalls = 0;
  Completer<InviteOverview>? delayed;
  final events = <String>[];
  @override
  Future<InviteOverview> activity() async {
    if (delayed != null) return delayed!.future;
    if (fail) throw const InviteFailure('CONFIG_SYNCING');
    return const InviteOverview(sampleActivity, null);
  }

  @override
  Future<InviteCode> code() async => sampleCode;
  @override
  Future<InviteRecords> records([String? cursor]) async {
    recordCalls++;
    return InviteRecords(
      [
        InviteRecord(
          cursor == null ? 'r1' : 'r2',
          '13800000000',
          '2026-10-05',
          10,
        ),
      ],
      2,
      cursor == null ? 'next' : null,
    );
  }

  @override
  Future<void> event(String period, String type, String eventId) async {
    events.add(type);
    if (failEvent) throw const InviteFailure('NETWORK');
  }
}

class FakeInviteDevice implements InviteDevice {
  final received = StreamController<String>.broadcast();
  String? initial, copied;
  Uint8List? image;
  bool saveResult = true;
  @override
  Stream<String> get links => received.stream;
  @override
  Future<String?> initialLink() async => initial;
  @override
  Future<void> copy(String text) async {
    copied = text;
  }

  @override
  Future<bool> savePoster(Uint8List png) async {
    image = png;
    return saveResult;
  }
}
