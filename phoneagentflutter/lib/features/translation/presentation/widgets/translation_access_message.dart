import '../../domain/translation_access.dart';

String translationAccessMessage(TranslationAccess access) {
  if (access.countryIso == null) {
    return access.forced
        ? '强制海外已开启；实际位置仍待确认，尚不能发起翻译通话'
        : '位置待确认，请在国家和地区中获取当前位置';
  }
  if (access.forced) return '强制海外已开启 · 实际位置 ${access.countryIso}';
  if (!access.overseasLocation) return '当前位置为中国；国内 SIP 翻译暂不迁移';
  return '当前位置 ${access.countryIso} · 使用海外翻译模型';
}
