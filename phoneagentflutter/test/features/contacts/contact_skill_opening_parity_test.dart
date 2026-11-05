import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_skill_opening.dart';
import 'package:phone_agent/features/home/data/home_config_mapper.dart';
import '../home/home_repository_test.dart' show fixture;

void main() {
  test(
    'published contact template survives mapping and personalizes opening',
    () {
      final dto = fixture()
        ..['skillRefs'] = [
          {
            'id': 'test_skill',
            'opening': '普通开场',
            'selectedContactOpening': '  想通知{contactName}吗？告诉我具体内容。  ',
          },
        ];
      final card = HomeConfigMapper(
        Uri.parse('https://example.test/sdk/'),
      ).parse(dto).cards.single;
      expect(card.opening, '普通开场');
      expect(
        contactSkillOpening(
          card.skillId!,
          ' 合成联系人 ',
          card.opening,
          template: card.selectedContactOpening,
        ),
        '想通知合成联系人吗？告诉我具体内容。',
      );
    },
  );

  test('template is optional and v66 known openings remain exact', () {
    expect(
      contactSkillOpening('restaurant_booking', '合成餐厅', ''),
      '想订合成餐厅？告诉我时间和人数就行，有其他要求也可以一起说。',
    );
    expect(
      contactSkillOpening('meeting_notification', '合成人员', ''),
      '要通知合成人员几点在哪开会？我来帮你打电话通知。',
    );
    expect(
      contactSkillOpening('business_event_invitation', '合成人员', ''),
      '要邀约什么活动？跟我说下主题、时间地点，还有以谁的名义打。',
    );
    expect(
      contactSkillOpening('unknown', '合成人员', '原开场', template: '  '),
      '原开场',
    );
    expect(
      contactSkillOpening(
        'restaurant_booking',
        ' ',
        '原开场',
        template: '替代{contactName}',
      ),
      '原开场',
    );
  });
}
