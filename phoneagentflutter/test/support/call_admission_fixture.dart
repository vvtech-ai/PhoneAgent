import 'package:phone_agent/features/calls/domain/call_admission.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import 'package:phone_agent/features/calls/domain/call_launch_request.dart';

CallLaunchRequest callRequest({
  String session = 'session',
  String tool = 'tool',
  int ordinal = 1,
  Map<String, Object?> spec = const {},
}) => CallLaunchRequest(
  sessionId: session,
  toolId: tool,
  commandId: 'command',
  ordinal: ordinal,
  spec: {
    'scene': 'synthetic',
    'targetName': '合成联系人',
    'phoneNumber': '+12025550101',
    'primaryGoal': '合成目的',
    ...spec,
  },
);

class AdmissionFixture
    implements CallAdmissionNoticeStore, CallAdmissionNoticeRepository {
  int? balance = 100, refreshed = 100;
  String? model;
  int refreshes = 0, commits = 0;
  bool readFails = false, writeFails = false;
  int retries = 0;
  Object? failure;
  final keys = <String>{};
  final waits = <Duration>[];
  Future<void> Function(Duration)? onWait;
  Future<int?> Function()? onRefresh;
  Future<bool> Function()? onRead;
  late final service = CallAdmissionService(
    store: this,
    notices: this,
    readBalance: () => balance,
    readModel: () => model,
    refreshBalance: () async {
      refreshes++;
      return onRefresh != null ? await onRefresh!() : refreshed;
    },
    wait: (duration) async {
      waits.add(duration);
      await onWait?.call(duration);
    },
  );
  @override
  Future<bool> wasNotified(String sessionId, Iterable<String> aliases) async {
    if (readFails) throw StateError('synthetic read');
    if (onRead != null) return onRead!();
    return aliases.any((alias) => keys.contains('$sessionId:$alias'));
  }

  @override
  Future<void> markNotified(String sessionId, Iterable<String> aliases) async {
    if (writeFails) throw StateError('synthetic write');
    keys.addAll(aliases.map((alias) => '$sessionId:$alias'));
  }

  @override
  Future<CallAdmissionNoticeReceipt> commit(CallLaunchRequest request) async {
    commits++;
    if (failure != null) throw failure!;
    if (commits <= retries) throw CallAdmissionNoticeFailure.retryable;
    return CallAdmissionNoticeReceipt(
      sessionId: request.sessionId,
      eventId: 'event',
      sequence: 1,
      created: commits == 1,
    );
  }
}
