/// Values shared by both platforms; no business actions or inferred status.
class RestaurantOptionPresentation {
  const RestaurantOptionPresentation({
    required this.ratingText,
    required this.priceCuisineText,
    required this.locationText,
    required this.openingStatus,
    required this.openingHours,
    this.address = '',
    this.phoneAvailable,
  });
  final String ratingText, priceCuisineText, locationText, openingHours;
  final String? openingStatus;
  final String address;
  final bool? phoneAvailable;
  String get phoneNotice => phoneAvailable == false ? '暂无可拨打电话' : '';

  String get locationStatusText => [
    locationText,
    if (openingStatus != null) openingStatus!,
    openingHours,
  ].where((s) => s.isNotEmpty).join(' · ');

  static RestaurantOptionPresentation? from(Map<String, Object?> item) {
    const advanced = [
      'averageCostYuan',
      'businessArea',
      'rating',
      'recommendedDishes',
      'cuisine',
      'openingHoursToday',
      'openingStatus',
    ];
    final tags = item['tags'];
    bool restaurantTag(Object? value) =>
        _text(value).toLowerCase() == 'restaurant' || _text(value) == '餐厅';
    if (!restaurantTag(item['category']) &&
        !(tags is List && tags.any(restaurantTag)) &&
        !advanced.any((key) => item[key] != null)) {
      return null;
    }
    final rating = _number(item['rating']);
    final cost = _number(item['averageCostYuan']);
    return RestaurantOptionPresentation(
      ratingText: rating == null ? '--' : '${rating.toStringAsFixed(1)}分',
      priceCuisineText: [
        if (cost != null) '¥${cost.toInt()}/人',
        _text(item['cuisine']),
      ].where((s) => s.isNotEmpty).join(' · '),
      locationText: [
        _text(item['businessArea']),
        optionDistanceText(item['distanceMeters']),
      ].where((s) => s.isNotEmpty).join(' · '),
      openingStatus: switch (_text(item['openingStatus']).toUpperCase()) {
        'OPEN' => '营业中',
        'CLOSED' => '未营业',
        _ => null,
      },
      openingHours: _text(item['openingHoursToday']),
      address: _text(item['address']),
      phoneAvailable: item['phoneAvailable'] is bool
          ? item['phoneAvailable'] as bool
          : null,
    );
  }

  static String _text(Object? value) => value is String ? value.trim() : '';
  static num? _number(Object? value) =>
      value is num && value.isFinite ? value : null;

  static String optionDistanceText(Object? value) {
    final number = _number(value);
    if (number == null) return '';
    final meters = number.toInt();
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)}km'
        : '${meters}m';
  }
}
