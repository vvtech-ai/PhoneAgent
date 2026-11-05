import 'package:flutter/material.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_identity_credentials_page.dart';

/// Independent synthetic UI only. No account, SDK, notification or call port.
void main() => runApp(const _Reference());

class _Reference extends StatefulWidget {
  const _Reference();
  @override
  State<_Reference> createState() => _ReferenceState();
}

class _ReferenceState extends State<_Reference> {
  TrustedIdentityVerification? _phase = TrustedIdentityVerification.verified;
  static const _large = bool.fromEnvironment('UI_REFERENCE_CREDENTIALS_LARGE');

  TrustedIncomingIdentity _identity(TrustedIdentityVerification phase) =>
      TrustedIncomingIdentity(
        owner: const TrustedCallerOwner('synthetic', 'synthetic-phone', 1),
        eventId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        verification: phase,
        displayType: phase == TrustedIdentityVerification.uncertified ? 6 : 0,
        name: _large ? '合成身份长名称合成身份长名称合成身份长名称' : '合成姓名',
        department: '合成部门',
        position: '合成职位',
        company: _large ? '合成企业长名称合成企业长名称合成企业长名称' : '合成企业',
        caller: '12025550100',
        target: 'synthetic-phone',
        sequence: 'synthetic-sequence',
        serial: 'synthetic-serial',
        issuer: '合成颁发机构',
        callTime: '合成日期',
        issuedAt: '合成日期',
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_large ? 2 : 1)),
      child: child!,
    ),
    home: _phase != null
        ? TrustedIdentityCredentialsPage(
            identity: _identity(_phase!),
            onBack: () => setState(() => _phase = null),
          )
        : Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('凭据页已关闭：独立演练未调用SDK'),
                    for (final phase in TrustedIdentityVerification.values)
                      TextButton(
                        onPressed: () => setState(() => _phase = phase),
                        child: Text('查看合成状态 ${phase.name}'),
                      ),
                  ],
                ),
              ),
            ),
          ),
  );
}
