import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/native_system_chrome.dart';
import '../../domain/trusted_incoming_identity.dart';
import '../widgets/trusted_identity_certificate.dart';
import '../widgets/trusted_identity_time.dart';

class TrustedIdentityCredentialsPage extends StatelessWidget {
  const TrustedIdentityCredentialsPage({
    required this.identity,
    required this.onBack,
    super.key,
  });
  final TrustedIncomingIdentity identity;
  final VoidCallback onBack;
  static const _assets = 'assets/images/trusted_identity/';
  static const _secondary = Color(0x8CFFFFFF);

  String get _status {
    if (identity.displayType == 6 ||
        identity.verification == TrustedIdentityVerification.uncertified) {
      return '此来电身份为未认证身份，建议您谨慎采信';
    }
    return switch (identity.verification) {
      TrustedIdentityVerification.pending => '正在验证来电身份…',
      TrustedIdentityVerification.failed => '来电身份验签失败，请谨慎采信',
      TrustedIdentityVerification.verified => '来电身份经可信身份认证 Powered by CHAKEN®',
      TrustedIdentityVerification.uncertified => '此来电身份为未认证身份，建议您谨慎采信',
    };
  }

  String get _name {
    final name = identity.name.isEmpty ? '可信身份' : identity.name;
    return switch (identity.displayType) {
      3 || 4 => identity.caller,
      1 => identity.position.isEmpty ? name : identity.position,
      2 => identity.department.isEmpty ? name : identity.department,
      _ => name,
    };
  }

  Widget _line(
    String text,
    double size, {
    Color color = _secondary,
    FontWeight weight = FontWeight.normal,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: 0,
    ),
  );

  Widget _defaultAvatar() => Image.asset(
    '${_assets}identity_card_avatar_default.png',
    width: 50,
    height: 50,
    fit: BoxFit.cover,
    semanticLabel: '来电头像',
  );

  Widget _header(BuildContext context) {
    final detail = [
      identity.department,
      identity.position,
    ].where((value) => value.isNotEmpty).join(' ');
    final company = identity.displayType == 1102
        ? identity.position
        : identity.company;
    final tags = [
      identity.job,
      if (identity.school.isNotEmpty) '毕业于${identity.school}',
    ].where((value) => value.isNotEmpty).join('  ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 62),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: identity.avatarData.isEmpty
                ? _defaultAvatar()
                : Image.memory(
                    Uint8List.fromList(identity.avatarData),
                    key: ValueKey('trusted-avatar-${identity.eventId}'),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    semanticLabel: '来电头像',
                    gaplessPlayback: false,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (MediaQuery.textScalerOf(context).scale(17) <= 20.4)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _name),
                        if (identity.title.isNotEmpty)
                          TextSpan(text: ' ${identity.title}'),
                        if (!{1, 2, 1102}.contains(identity.displayType) &&
                            detail.isNotEmpty)
                          TextSpan(
                            text: ' $detail',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _secondary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      letterSpacing: 0,
                    ),
                  )
                else
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      _line(
                        _name,
                        17,
                        color: Colors.white,
                        weight: FontWeight.w500,
                      ),
                      if (identity.title.isNotEmpty)
                        _line(
                          identity.title,
                          17,
                          color: Colors.white,
                          weight: FontWeight.w500,
                        ),
                      if (!{1, 2, 1102}.contains(identity.displayType) &&
                          detail.isNotEmpty)
                        _line(detail, 12),
                    ],
                  ),
                if (company.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _line(company, 12),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _line(tags, 11, color: const Color(0xB3FFFFFF)),
                ],
                if (!{3, 4}.contains(identity.displayType) &&
                    identity.caller.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _line(identity.caller, 13),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NativeSystemChrome.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF383B40),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              '${_assets}call_credentials_bg_icon.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            const ColoredBox(color: Color(0x4D000000)),
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xB8000000),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _header(context),
                            const SizedBox(height: 12),
                            const Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Color(0x33FFFFFF),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xB8FFFFFF),
                                  height: 1.2,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (identity.hasCertificate) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: TrustedIdentityCertificate(
                                  identity: identity,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '本凭证仅用于证明${trustedIdentityTime(identity.callTime)}通话主叫身份',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0x73FFFFFF),
                                  height: 1.2,
                                  letterSpacing: 0,
                                ),
                              ),
                            ] else
                              const SizedBox(height: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      button: true,
                      label: '返回首页',
                      child: InkWell(
                        onTap: onBack,
                        borderRadius: BorderRadius.circular(25),
                        child: Image.asset(
                          '${_assets}call_credentials_home_icon.png',
                          width: 50,
                          height: 50,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
