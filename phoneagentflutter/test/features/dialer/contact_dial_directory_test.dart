import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/contact_dial_input.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';

const _directory = TranslationDirectory(
  version: 1,
  countries: [
    TranslationDirectoryCountry('GB', '+44', '英国', 'en', [], '', ''),
    TranslationDirectoryCountry('US', '+1', '美国', 'en', [], '', r'202\d{7}'),
    TranslationDirectoryCountry('CA', '+1', '加拿大', 'en', [], '', r'416\d{7}'),
    TranslationDirectoryCountry('BS', '+1242', '巴哈马', 'en', [], '', ''),
  ],
  models: [],
  languages: [],
);

void main() {
  test('international detection uses countries from current directory', () {
    expect(contactDialInput('+44 20 1234 5678', directory: _directory), (
      iso: 'GB',
      number: '2012345678',
      error: '',
    ));
    expect(
      contactDialInput('0086 13800138000', directory: _directory).error,
      contains('暂不支持'),
    );
    expect(
      contactDialInput(
        '2012345678',
        defaultIso: 'gb',
        directory: _directory,
      ).iso,
      'GB',
    );
  });

  test('longest international prefix wins over directory order', () {
    expect(contactDialInput('+1 242 5550123', directory: _directory), (
      iso: 'BS',
      number: '5550123',
      error: '',
    ));
  });

  test(
    'shared calling code uses directory phone rules before preferred country',
    () {
      expect(
        contactDialInput(
          '+1 416-555-0123',
          defaultIso: 'US',
          directory: _directory,
        ).iso,
        'CA',
      );
      expect(
        contactDialInput(
          '+1 202-555-0123',
          defaultIso: 'CA',
          directory: _directory,
        ).iso,
        'US',
      );
      expect(
        contactDialInput(
          '+1 604-555-0123',
          defaultIso: 'CA',
          directory: _directory,
        ).iso,
        'CA',
      );
      expect(
        contactDialInput('+1 604-555-0123', directory: _directory).error,
        contains('暂不支持'),
      );
      expect(
        contactDialInput(
          '+1 104-555-0123',
          defaultIso: 'CA',
          directory: _directory,
        ).error,
        contains('格式'),
      );
    },
  );

  test('empty runtime directory does not fall back to static countries', () {
    const empty = TranslationDirectory(
      version: 1,
      countries: [],
      models: [],
      languages: [],
    );
    expect(
      contactDialInput('+86 13800138000', directory: empty).error,
      contains('暂不支持'),
    );
    expect(
      contactDialInput('13800138000', directory: empty).error,
      contains('暂不支持'),
    );
  });
}
