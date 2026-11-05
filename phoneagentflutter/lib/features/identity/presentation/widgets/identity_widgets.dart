import '../../../../core/design/native_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/design/native_gradient_action.dart';

/// Shared MyIdentityProfileComponents / AIIdentityInit presentation.
abstract final class IdentityStyle {
  static const ink = Color(0xFF111111), muted = Color(0xFF6E6E73);
  static const line = Color(0xFFE5E5EA), danger = Color(0xFFE14D46);
  static const body = TextStyle(fontSize: 16, color: ink);
  static const heading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: ink,
  );
}

class IdentityCard extends StatelessWidget {
  const IdentityCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.editor = false,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool editor;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(editor ? 18 : 22),
      border: Border.all(
        color: editor ? const Color(0x143C3C43) : const Color(0xC7FFFFFF),
      ),
      boxShadow: editor
          ? null
          : const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class IdentityAction extends StatelessWidget {
  const IdentityAction({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.ghost = false,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final bool danger, ghost;
  @override
  Widget build(BuildContext context) => NativeGradientAction(
    label: label,
    onPressed: onTap,
    tone: ghost
        ? NativeActionTone.secondary
        : danger
        ? NativeActionTone.danger
        : NativeActionTone.primary,
  );
}

class IdentityIconButton extends StatelessWidget {
  const IdentityIconButton({
    required this.label,
    required this.asset,
    required this.onTap,
    this.edit = false,
    super.key,
  });
  final String label;
  final int asset;
  final VoidCallback? onTap;
  final bool edit;
  void _activate(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isCurrent != false) {
      onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    foregroundDecoration: edit
        ? BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0x1A3C3C43)),
          )
        : null,
    child: Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap == null ? null : () => _activate(context),
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onTap == null ? null : () => _activate(context),
        padding: EdgeInsets.zero,
        icon: !edit && (asset == 1 || asset == 2)
            ? Icon(
                asset == 2 ? Icons.edit_rounded : Icons.delete_outline_rounded,
                size: asset == 2 ? 21 : 22,
                color: asset == 2 ? IdentityStyle.ink : IdentityStyle.danger,
              )
            : SvgPicture.asset(
                'assets/images/identity/identity_$asset.svg',
                width: asset == 0
                    ? 24
                    : edit
                    ? 20
                    : 21,
                height: asset == 0
                    ? 24
                    : edit
                    ? 20
                    : 21,
              ),
      ),
    ),
  );
}

class IdentityDeleteDialog extends StatelessWidget {
  const IdentityDeleteDialog({super.key});
  @override
  Widget build(BuildContext context) => const NativeConfirmationDialog(
    title: '删除身份',
    message: '删除后将清除身份信息、全部模型的当前及候选克隆音色，以及本地认证录音。该操作不可恢复，是否继续？',
    confirmLabel: '删除身份',
    danger: true,
  );
}
