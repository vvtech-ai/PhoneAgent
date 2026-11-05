import 'dart:async';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_input_session.dart';

class InputPermissionFake implements ConversationPermissionSource {
  PermissionGrant grant = PermissionGrant.granted;
  Completer<PermissionGrant>? gate;
  final requests = <bool>[];
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    return gate == null ? grant : gate!.future;
  }
}

class VoiceInputFake implements VoiceInputSession {
  final controller = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  int starts = 0, stops = 0, releases = 0;
  bool failStop = false;
  Completer<void>? stopGate;
  @override
  Stream<VoiceGatewayEvent> get events => controller.stream;
  void emit(VoiceGatewayEvent event) => controller.add(event);
  @override
  Future<void> start(Uri endpoint) async {
    starts++;
  }

  @override
  Future<void> release() async {
    releases++;
  }

  @override
  Future<void> cancel() async {
    stops++;
    if (failStop) throw StateError('synthetic stop failure');
    if (stopGate != null) await stopGate!.future;
  }
}
