import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';

void main() {
  test(
    'apology opens with local voice consent and refuses unconfirmed task input',
    () {
      final gateway = OfflineAgent();
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'apology',
          skillId: 'apology_master',
          opening: '欢迎来到认错热线。',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: OfflineHistory(),
      );
      addTearDown(controller.dispose);
      expect(
        controller.state.messages.map((m) => m.text),
        contains(contains('道歉需要使用您的克隆音色')),
      );
      controller.send('帮我向伴侣道歉，昨天我迟到了');
      expect(gateway.commands, isEmpty);
    },
  );
}
