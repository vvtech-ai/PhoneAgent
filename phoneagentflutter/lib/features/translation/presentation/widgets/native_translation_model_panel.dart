import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/design/native_model_refresh_button.dart';

Future<T?> showNativeTranslationModelPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  useRootNavigator: false,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x73000000),
  transitionDuration: Theme.of(context).platform == TargetPlatform.iOS
      ? const Duration(milliseconds: 300)
      : Duration.zero,
  transitionBuilder: (context, animation, secondary, child) =>
      FadeTransition(opacity: animation, child: child),
  pageBuilder: (context, animation, secondary) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: builder(context),
    ),
  ),
);

/// Native sheet geometry only; all selection and request ownership stays outside.
class NativeTranslationModelPanel extends StatelessWidget {
  const NativeTranslationModelPanel({
    super.key,
    required this.children,
    required this.busy,
    required this.onRefresh,
    required this.onClose,
    this.refreshKey,
  });
  final List<Widget> children;
  final bool busy;
  final VoidCallback? onRefresh;
  final VoidCallback onClose;
  final Key? refreshKey;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final media = MediaQuery.of(context);
    final maxHeight = math.max(0.0, media.size.height - media.padding.top);
    final content = Column(
      mainAxisSize: ios ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 24, ios ? 8 : 20, 20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '选择实时翻译模型',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              NativeModelRefreshButton(
                key: refreshKey,
                busy: busy,
                size: 44,
                onRefresh: onRefresh,
              ),
              if (ios) const SizedBox(width: 4),
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close,
                    size: 22,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          fit: ios ? FlexFit.tight : FlexFit.loose,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 32),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '切换后将在下次翻译通话时生效',
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: Color(0xFF8B8FA3),
              ),
            ),
          ),
        ),
      ],
    );
    return Material(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ios
            ? SizedBox(height: math.min(436, maxHeight), child: content)
            : content,
      ),
    );
  }
}
