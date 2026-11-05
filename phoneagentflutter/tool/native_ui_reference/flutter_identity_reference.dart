import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/controller/identity_controller.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_page.dart';

/// Matching synthetic profile states; all identity/business actions are empty.
class FlutterIdentityReference extends StatelessWidget {
  const FlutterIdentityReference({super.key, required this.scene});
  final String scene;
  IdentityProfile get _profile => IdentityProfile(
    accountId: 'synthetic-reference',
    name: scene == 'identity-empty' ? '' : '演练用户',
    gender: '不透露',
    contactPhone: '',
    verificationStatus: scene.contains('verified') ? 'VERIFIED' : '',
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
      child: SafeArea(
        child: IdentityPage(
          state: IdentityState(
            profile: _profile,
            draft: IdentityDraft.from(_profile),
            editing: scene.endsWith('-edit'),
            operation: scene == 'identity-loading'
                ? IdentityOperation.loading
                : IdentityOperation.idle,
            loadFailed: scene == 'identity-error',
            error: scene == 'identity-error' ? '身份资料加载失败，请重试' : '',
          ),
          actions: IdentityActions(
            back: () {},
            retry: () {},
            edit: () {},
            cancel: () {},
            save: () {},
            delete: () {},
            models: () {},
            name: (_) {},
            phone: (_) {},
            gender: (_) {},
          ),
        ),
      ),
    ),
  );
}
