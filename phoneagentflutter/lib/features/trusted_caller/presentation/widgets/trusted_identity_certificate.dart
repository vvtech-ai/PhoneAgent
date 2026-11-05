import 'package:flutter/material.dart';
import '../../domain/trusted_incoming_identity.dart';
import 'trusted_identity_time.dart';

class TrustedIdentityCertificate extends StatelessWidget {
  const TrustedIdentityCertificate({required this.identity, super.key});
  final TrustedIncomingIdentity identity;
  static const _assets = 'assets/images/trusted_identity/';
  static const _primary = Color(0xFF304F7A);
  static const _secondary = Color(0xFF45638C);

  Widget _text(
    String value,
    double size, {
    FontWeight weight = FontWeight.normal,
    Color color = _secondary,
  }) => Text(
    value,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.2,
      letterSpacing: 0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!identity.hasCertificate) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final company = identity.company;
        final detailScale = MediaQuery.textScalerOf(context).scale(9.5) / 9.5;
        final bottomInset = 38.0 * (detailScale < 1 ? 1.0 : detailScale);
        return IntrinsicHeight(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxWidth * 1.438,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '${_assets}id_card_view_image.png',
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(32, 60, 32, bottomInset),
                  child: Column(
                    children: [
                      Image.asset(
                        '${_assets}id_card_chaken_image.png',
                        width: constraints.maxWidth * 0.70,
                        height: 9,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(height: 8),
                      Image.asset(
                        '${_assets}id_card_title_image.png',
                        width: constraints.maxWidth * 0.66,
                        height: 32,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(height: 2),
                      _text(
                        '可信身份凭证',
                        17,
                        weight: FontWeight.w500,
                        color: _primary,
                      ),
                      const SizedBox(height: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              '${_assets}id_card_tag1_image.png',
                              width: 15,
                              height: 6,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: _text(
                                identity.name.isEmpty ? '可信身份' : identity.name,
                                18,
                                weight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Image.asset(
                              '${_assets}id_card_tag2_image.png',
                              width: 15,
                              height: 6,
                              excludeFromSemantics: true,
                            ),
                          ],
                        ),
                      ),
                      if (identity.department.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        _text(identity.department, 13),
                      ],
                      if (identity.position.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        _text(identity.position, 13),
                      ],
                      const SizedBox(height: 10),
                      Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Image.asset(
                            '${_assets}id_card_ca_image.png',
                            width: 100,
                            height: 60,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Column(
                              children: [
                                _text('认证企业', 13, weight: FontWeight.bold),
                                const SizedBox(height: 1),
                                if (company.isNotEmpty)
                                  _text(company, 13, weight: FontWeight.w500),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Text(
                            '编号：${identity.serial.isEmpty ? '--' : identity.serial}\n'
                            '认证时间：${trustedIdentityTime(identity.issuedAt)}\n'
                            '颁发机构：${identity.issuer.isEmpty ? '--' : identity.issuer}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF405E87),
                              height: 1.4,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
