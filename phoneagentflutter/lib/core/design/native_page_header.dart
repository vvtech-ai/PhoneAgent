import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Full-page navigation only. The parent owns SafeArea and the background.
class NativePageHeader extends StatelessWidget {
  const NativePageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.showBack = true,
    this.backKey,
    this.trailing,
    this.backgroundColor,
    this.foregroundColor = const Color(0xFF0F172A),
  });

  final String title;
  final VoidCallback? onBack;
  final bool showBack;
  final Key? backKey;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _HeaderLayout(
        children: [
          if (showBack)
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: backKey,
                tooltip: '返回',
                padding: EdgeInsets.zero,
                onPressed: onBack == null
                    ? null
                    : () {
                        if (context.mounted &&
                            ModalRoute.of(context)?.isCurrent != false) {
                          onBack!();
                        }
                      },
                icon: Icon(
                  Icons.keyboard_arrow_left,
                  size: 30,
                  color: foregroundColor,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ),
          if (trailing != null)
            IntrinsicWidth(child: trailing!)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
    return backgroundColor == null
        ? header
        : ColoredBox(color: backgroundColor!, child: header);
  }
}

/// Keeps AppBar's system insets and the caller's original background.
class NativePageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NativePageAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBack,
    this.trailing,
    this.backgroundColor,
  });
  final String title;
  final VoidCallback? onBack;
  final bool? showBack;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final canReturn = showBack ?? (onBack != null || Navigator.canPop(context));
    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: NativePageHeader(
        title: title,
        showBack: canReturn,
        onBack:
            onBack ??
            (showBack == null && canReturn
                ? () => Navigator.maybePop(context)
                : null),
        trailing: trailing,
      ),
    );
  }
}

class _HeaderLayout extends MultiChildRenderObjectWidget {
  const _HeaderLayout({required super.children});
  @override
  RenderObject createRenderObject(BuildContext context) => _HeaderRenderBox();
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

/// Measures both sides before laying out the title, without a post-frame jump.
class _HeaderRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  @override
  void performLayout() {
    final left = firstChild!;
    final title = childAfter(left)!;
    final right = childAfter(title)!;
    final width = constraints.maxWidth;
    // A finite title allowance also constrains unusually long action labels.
    final sideMax = math.max(0.0, (width - 24) / 2);
    final sideConstraints = BoxConstraints(
      maxWidth: sideMax,
      maxHeight: constraints.maxHeight,
    );
    left.layout(sideConstraints, parentUsesSize: true);
    right.layout(sideConstraints, parentUsesSize: true);
    final side = math.max(left.size.width, right.size.width);
    title.layout(
      BoxConstraints(
        minWidth: math.max(0.0, width - 2 * side),
        maxWidth: math.max(0.0, width - 2 * side),
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(
        width,
        math.max(
          64,
          math.max(
            title.size.height,
            math.max(left.size.height, right.size.height),
          ),
        ),
      ),
    );
    void position(RenderBox child, double x) {
      (child.parentData! as _HeaderParentData).offset = Offset(
        x,
        (size.height - child.size.height) / 2,
      );
    }

    position(left, 0);
    position(title, side);
    position(right, width - right.size.width);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
