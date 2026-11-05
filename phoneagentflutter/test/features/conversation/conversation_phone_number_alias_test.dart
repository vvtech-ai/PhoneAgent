import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';

void main() {
  test('contact option preserves phoneNumber when phone is absent', () {
    final option = ConversationMessages.options({
      'items': [
        {
          'label': '杜燕',
          'phoneNumber': '13800000000',
          'tags': ['contact'],
        },
      ],
    }).single;

    expect(option.phone, '13800000000');
    expect(option.detail, contains('13800000000'));
    expect(option.isContact, isTrue);
  });

  test('phone remains the preferred alias when both fields are present', () {
    final option = ConversationMessages.options({
      'items': [
        {'label': '杜燕', 'phone': '13800000001', 'phoneNumber': '13800000000'},
      ],
    }).single;

    expect(option.phone, '13800000001');
    expect(option.detail, contains('13800000001'));
    expect(option.detail, isNot(contains('13800000000')));
  });
}
