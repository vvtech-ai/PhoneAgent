class DialCountry {
  const DialCountry(this.iso, this.name, this.code, this.pinyin, this.initials);
  final String iso, name, code, pinyin, initials;
  String get section => iso.substring(0, 1);
  bool get inG20 => const {'CN', 'JP', 'US'}.contains(iso);
  String get flagAsset =>
      'assets/images/dialer/flag_dial_${iso.toLowerCase()}.png';
  bool matches(String query) {
    final q = query.trim().toLowerCase().replaceAll(' ', '');
    return [
      iso,
      name,
      code,
      pinyin,
      initials,
    ].any((s) => s.toLowerCase().contains(q));
  }
}

const dialCountries = [
  DialCountry('CN', '中国', '+86', 'zhongguo', 'zg'),
  DialCountry('JP', '日本', '+81', 'riben', 'rb'),
  DialCountry('SG', '新加坡', '+65', 'xinjiapo', 'xjp'),
  DialCountry('US', '美国', '+1', 'meiguo', 'mg'),
];
DialCountry? dialCountry(String iso) {
  for (final country in dialCountries) {
    if (country.iso == iso.toUpperCase()) return country;
  }
  return null;
}
