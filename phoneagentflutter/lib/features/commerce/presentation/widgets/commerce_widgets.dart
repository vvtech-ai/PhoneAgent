import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_action_style.dart';
import '../../../../core/design/native_card_style.dart';
import '../../../../core/design/native_page_background.dart';

class CommerceScaffold extends StatelessWidget {
  const CommerceScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
    this.action,
  });
  final String title;
  final VoidCallback onBack;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(
        context,
      ).colorScheme.copyWith(primary: const Color(0xFF0A84FF)),
    ),
    child: NativePageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NativePageAppBar(
          title: title,
          textScaler: MediaQuery.textScalerOf(context),
          onBack: onBack,
          backgroundColor: Colors.transparent,
          trailing: action,
        ),
        body: SafeArea(child: child),
      ),
    ),
  );
}

class CommerceCard extends StatelessWidget {
  const CommerceCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.marginBottom = 10,
    this.contentPadding,
    this.offer = false,
  });
  final Widget child;
  final double padding;
  final double marginBottom;
  final EdgeInsetsGeometry? contentPadding;
  final bool offer;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: marginBottom),
    padding: contentPadding ?? EdgeInsets.all(padding),
    decoration: offer
        ? const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0E0F172A),
                blurRadius: 18,
                offset: Offset(0, 5),
              ),
            ],
          )
        : NativeCardStyle.decoration,
    child: child,
  );
}

class CommerceAction extends StatelessWidget {
  const CommerceAction(
    this.label, {
    super.key,
    this.onPressed,
    this.secondary = false,
    this.busy = false,
    this.backgroundColor,
    this.minHeight = 50,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool busy;
  final Color? backgroundColor;
  final double minHeight;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: NativeActionStyle.decoration(
        enabled: !busy && onPressed != null,
        tone: secondary ? NativeActionTone.secondary : NativeActionTone.primary,
        backgroundColor: backgroundColor,
      ),
      child: FilledButton(
        style: NativeActionStyle.buttonStyle(
          context,
          tone: secondary
              ? NativeActionTone.secondary
              : NativeActionTone.primary,
        ).copyWith(minimumSize: WidgetStatePropertyAll(Size(0, minHeight))),
        onPressed: busy ? null : onPressed,
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    ),
  );
}

class PointsSpark extends StatelessWidget {
  const PointsSpark({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CustomPaint(painter: _SparkPainter()),
  );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w * .6, h * .4, w, h / 2)
      ..quadraticBezierTo(w * .6, h * .6, w / 2, h)
      ..quadraticBezierTo(w * .4, h * .6, 0, h / 2)
      ..quadraticBezierTo(w * .4, h * .4, w / 2, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC400));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String commerceDate(DateTime? date) {
  if (date == null) return '—';
  final wall = date.toUtc().add(const Duration(hours: 8));
  return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
}

String commerceDateTime(DateTime date) {
  final wall = date.toUtc().add(const Duration(hours: 8));
  return '${commerceDate(date)} ${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}（北京时间）';
}
