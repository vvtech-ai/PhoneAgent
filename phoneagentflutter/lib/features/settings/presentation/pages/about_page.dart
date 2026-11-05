import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_setting_controls.dart';
import '../../../auth/domain/legal_document_port.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.version,
    required this.onDocument,
    this.showUpdate = false,
    this.updateSummary = '',
    this.updateTitle = '版本更新',
    this.onUpdate,
    this.onAccount,
  });
  final String version;
  final bool showUpdate;
  final String updateSummary, updateTitle;
  final VoidCallback? onUpdate, onAccount;
  final ValueChanged<LegalDocument> onDocument;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: NativePageBackground(
      child: SafeArea(
        child: Column(
          children: [
            NativePageHeader(
              title: '关于PhoneAgent',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/about_brand_logo.png',
                        width: 96,
                        height: 96,
                        semanticLabel: 'PhoneAgent 图标',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PhoneAgent',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  if (version.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      version,
                      key: const Key('about-version'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  for (final entry in const {
                    LegalDocument.userAgreement: '用户协议',
                    LegalDocument.privacyPolicy: '隐私协议',
                    LegalDocument.personalInformation: '个人信息明示清单',
                  }.entries)
                    NativeSettingCard(
                      key: ValueKey('about-${entry.key.name}'),
                      title: entry.value,
                      subtitle: '',
                      value: '›',
                      onTap: () => onDocument(entry.key),
                    ),
                  if (showUpdate)
                    NativeSettingCard(
                      key: const Key('about-update'),
                      isAction: true,
                      title: updateTitle,
                      subtitle: '',
                      value: updateSummary,
                      onTap: onUpdate,
                    ),
                  NativeSettingCard(
                    key: const Key('about-account'),
                    isAction: true,
                    title: '账号管理',
                    subtitle: '',
                    value: '›',
                    onTap: onAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
