import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_page_background.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.onDelete, required this.onBack});
  final VoidCallback? onDelete, onBack;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: onBack != null,
    child: Scaffold(
      body: NativePageBackground(
        child: SafeArea(
          child: Column(
            children: [
              NativePageHeader(title: '账号管理', onBack: onBack),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [_DeletionRow(onTap: onDelete)],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DeletionRow extends StatelessWidget {
  const _DeletionRow({required this.onTap});
  final VoidCallback? onTap;
  static const red = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('account-delete'),
    button: true,
    enabled: onTap != null,
    label: '注销账号，注销账号及相关个人数据',
    onTap: onTap,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xC7FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14101114),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '注销账号',
                          style: TextStyle(
                            fontSize: 16,
                            height: 20 / 16,
                            fontWeight: FontWeight.w700,
                            color: red,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '注销账号及相关个人数据',
                          style: TextStyle(
                            fontSize: 13,
                            height: 19 / 13,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 16,
                    child: Text(
                      '›',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
