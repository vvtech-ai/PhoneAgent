import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/attachments/data/api_document_parser.dart';
import '../features/attachments/data/platform_document_picker.dart';
import '../features/attachments/presentation/controller/document_import_controller.dart';
import '../features/conversation/presentation/controller/conversation_controller.dart';
import 'business_providers.dart';
import '../features/attachments/data/platform_agent_document_picker.dart';
import '../features/attachments/presentation/controller/agent_document_controller.dart';

final agentDocumentFactoryProvider =
    Provider.autoDispose<AgentDocumentController Function()>((ref) {
      final parser = ApiDocumentParser(
        ref.watch(accountApiProvider),
        agentRequest: true,
      );
      return () =>
          AgentDocumentController(const PlatformAgentDocumentPicker(), parser);
    });

final documentImportFactoryProvider =
    Provider.autoDispose<DocumentImportController Function()>((ref) {
      final parser = ApiDocumentParser(ref.watch(accountApiProvider));
      return () => DocumentImportController(
        const PlatformDocumentPicker(),
        parser,
        newConversationId,
      );
    });
