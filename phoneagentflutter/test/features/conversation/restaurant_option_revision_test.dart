import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_content_revision.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_option_values.dart';

ConversationMessage message({double rating = 4.7, String phone = '00000'}) =>
    ConversationMessage(
      id: 'same',
      role: MessageRole.assistant,
      text: '合成候选',
      options: ConversationMessages.options({
        'items': [
          {
            'label': '合成餐厅',
            'rating': rating,
            'phone': phone,
            'openingStatus': 'OPEN',
            'averageCostYuan': 88,
          },
        ],
      }),
    );

void main() {
  test('restaurant visible values update revision, hidden details do not', () {
    ConversationContentRevision revision(ConversationMessage value) =>
        ConversationContentRevision('session', [value]);
    expect(revision(message()), revision(message()));
    expect(revision(message()), revision(message(phone: '11111')));
    expect(revision(message()), isNot(revision(message(rating: 4.8))));
    final before = conversationOptionValues(message());
    expect(before, conversationOptionValues(message(phone: '11111')));
    expect(before, isNot(conversationOptionValues(message(rating: 4.8))));
    expect(() => before.add('hidden'), throwsUnsupportedError);
  });
  test('switching restaurant to generic is a visible update', () {
    final generic = ConversationMessage(
      id: 'same',
      role: MessageRole.assistant,
      text: '合成候选',
      options: const [ConversationOption('合成餐厅', '合成说明')],
    );
    expect(
      conversationOptionValues(message()),
      isNot(conversationOptionValues(generic)),
    );
  });
}
