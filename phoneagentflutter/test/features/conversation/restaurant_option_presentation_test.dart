import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/restaurant_option_presentation.dart';

void main() {
  test('server restaurant fields survive option projection', () {
    final option = ConversationMessages.options({
      'items': [
        {
          'label': '合成餐厅',
          'category': 'restaurant',
          'rating': 4.7,
          'averageCostYuan': 88,
          'cuisine': ' 粤菜 ',
          'businessArea': '合成商圈',
          'distanceMeters': 1250,
          'openingStatus': ' open ',
          'openingHoursToday': '10:00–22:00',
        },
      ],
    }).single;
    expect(option.restaurant!.ratingText, '4.7分');
    expect(option.restaurant!.priceCuisineText, '¥88/人 · 粤菜');
    expect(
      option.restaurant!.locationStatusText,
      '合成商圈 · 1.3km · 营业中 · 10:00–22:00',
    );
  });
  test('classification and unknown data do not invent business facts', () {
    expect(RestaurantOptionPresentation.from({'label': '合成联系人'}), isNull);
    for (final tag in ['RESTAURANT', '餐厅']) {
      final value = RestaurantOptionPresentation.from({
        'tags': [tag],
      })!;
      expect(value.ratingText, '--');
      expect(value.locationStatusText, '');
      expect(value.openingStatus, isNull);
    }
    final value = RestaurantOptionPresentation.from({
      'rating': double.nan,
      'averageCostYuan': '88',
      'openingStatus': 'UNKNOWN',
      'distanceMeters': double.infinity,
    })!;
    expect(value.ratingText, '--');
    expect(value.priceCuisineText, '');
    expect(value.locationStatusText, '');
    expect(
      RestaurantOptionPresentation.from({
        'openingStatus': 'CLOSED',
      })!.openingStatus,
      '未营业',
    );
  });
  test('generic details trim deduplicate and retain native distance', () {
    final option = ConversationMessages.options({
      'items': [
        {
          'label': '合成联系人',
          'detail': ' 测试说明 ',
          'address': '测试说明',
          'phone': '00000',
          'distanceMeters': 900,
        },
      ],
    }).single;
    expect(option.detail, '测试说明 | 00000 | 900m');
    expect(option.restaurant, isNull);
  });
}
