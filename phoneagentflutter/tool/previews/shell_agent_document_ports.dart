import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/attachment_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/attachments/domain/agent_document_request.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/presentation/controller/agent_document_controller.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

import 'agent_document_preview_ports.dart';
import 'shell_conversation_ports.dart';

const shellAgentDocumentEnabled = bool.fromEnvironment('UI_AGENT_DOCUMENT');

final shellAgentDocumentPortsProvider = Provider<ShellAgentDocumentPorts>((
  ref,
) {
  ref.watch(loginEpochProvider);
  final ports = ShellAgentDocumentPorts(
    ref.watch(shellConversationPortsProvider),
  );
  ref.onDispose(ports.close);
  return ports;
});

List<Override> shellAgentDocumentOverrides() => [
  agentDocumentFactoryProvider.overrideWith((ref) {
    final ports = ref.watch(shellAgentDocumentPortsProvider);
    return () => AgentDocumentController(ports, ports);
  }),
];

/// Opt-in ordinary-App capture only. Never reads a real file or sends HTTP.
class ShellAgentDocumentPorts extends AgentDocumentPreviewPorts {
  ShellAgentDocumentPorts(this.delegate, {int? parseDelayMillis})
    : parseDelayMillis =
          (parseDelayMillis ??
                  const int.fromEnvironment('UI_DOCUMENT_PARSE_DELAY_MS'))
              .clamp(0, 10000);

  final ShellConversationPorts delegate;
  final int parseDelayMillis;
  final _sessions = <String>{};
  bool _closed = false;

  void close() => _closed = true;

  void _check() {
    if (_closed) throw StateError('MOCK document capture owner closed');
  }

  @override
  AgentRun start(AgentCommand command) {
    _check();
    if (command.message == 'ui-document') _sessions.add(command.sessionId);
    if (command.message == 'ui-document' ||
        command.message == '继续' && _sessions.contains(command.sessionId) ||
        command.actionId == 'submit_document' &&
            _sessions.contains(command.sessionId)) {
      return super.start(command);
    }
    return delegate.start(command);
  }

  @override
  Future<SelectedDocument?> pick(AgentDocumentRequest request) {
    _check();
    return super.pick(request);
  }

  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async {
    _check();
    if (parseDelayMillis > 0) {
      await Future<void>.delayed(Duration(milliseconds: parseDelayMillis));
    }
    _check();
    return super.parse(file, bytes);
  }
}
