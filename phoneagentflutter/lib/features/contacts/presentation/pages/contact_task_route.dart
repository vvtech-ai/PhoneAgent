import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/conversation_providers.dart';
import '../../../conversation/presentation/controller/conversation_controller.dart';
import '../../../conversation/presentation/controller/conversation_state.dart';
import '../../../conversation/presentation/pages/conversation_page.dart';
import '../../../conversation/presentation/pages/conversation_route.dart';
import '../../data/preview_contact_agent.dart';
import '../../data/preview_contacts.dart';
import '../../data/lpinyin_contact_dictionary.dart';
import '../../../conversation/domain/tools/phone_contact_lookup.dart';
import '../../../conversation/domain/tools/name_contact_lookup.dart';

class ContactTaskRoute extends StatelessWidget {
  const ContactTaskRoute({
    super.key,
    required this.entry,
    required this.preview,
  });
  final ConversationEntry entry;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    if (!preview) return ConversationRoute(entry: entry);
    return ProviderScope(
      overrides: [
        conversationControllerProvider(entry).overrideWith((ref) {
          final port = PreviewContactAgent(lookup: true);
          return ConversationController(
            entry: entry,
            accountId: 'MOCK',
            gateway: port,
            history: port,
            contactLookup: PhoneContactLookup(PreviewContacts(), port),
            nameContactLookup: NameContactLookup(
              PreviewContacts(),
              port,
              const LpinyinContactDictionary(),
            ),
          );
        }),
      ],
      child: _PreviewConversation(entry: entry),
    );
  }
}

class _PreviewConversation extends ConsumerWidget {
  const _PreviewConversation({required this.entry});
  final ConversationEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(conversationControllerProvider(entry).notifier);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF3CD),
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'MOCK · 离线回复 · 不创建任务 / 不拨号',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ConversationPage(
                  state: ref.watch(conversationControllerProvider(entry)),
                  modelName: 'MOCK',
                  onClose: () {
                    controller.close();
                    Navigator.pop(context);
                  },
                  onToggle: controller.toggleInput,
                  onSend: controller.send,
                  onChoose: controller.choose,
                  onRetry: controller.restore,
                  onNotice: controller.showNotice,
                  onModels: () => controller.showNotice('离线演练不修改账号模型或音色'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
