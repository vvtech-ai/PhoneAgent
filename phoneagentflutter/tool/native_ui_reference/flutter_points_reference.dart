import 'package:flutter/material.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';

/// Only a production page and synthetic state; no provider, wallet or invite IO.
class FlutterPointsReference extends StatelessWidget {
  const FlutterPointsReference({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth > 0 && bounds.maxHeight > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _recordMetrics(context);
        });
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        body: SafeArea(
          child: PointsWalletPage(
            state: const PointsWalletState(
              account: PointsAccount(
                availableBalance: 900,
                totalBalance: 900,
                heldBalance: 0,
                updatedAt: '2026-09-20T09:00:00Z',
                todayDailyGrantPoints: 100,
              ),
            ),
            onBack: () {},
            onLedger: () {},
            onRefresh: () async {},
          ),
        ),
      );
    },
  );
}

void _recordMetrics(BuildContext context) {
  const labels = {
    '当前可用积分': 'caption',
    '900': 'balance',
    '积分流水  ›': 'ledger',
    '✦': 'star',
    '约可通话 9 分钟 · 今日赠送100积分已到账': 'summary',
  };
  void visit(Element element) {
    final widget = element.widget;
    String? label;
    if (widget is Text) label = labels[widget.data];
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      final decoration = widget.decoration as BoxDecoration;
      if (decoration.color == Colors.white &&
          decoration.borderRadius == BorderRadius.circular(18)) {
        label = 'balance-card';
      }
    }
    if (label != null) {
      final render = element.findRenderObject();
      if (render is RenderBox &&
          render.hasSize &&
          render.attached &&
          render.size.width > 0) {
        final origin = render.localToGlobal(Offset.zero);
        debugPrint(
          'UI_REFERENCE_METRIC:$label:${origin.dx},${origin.dy},${render.size.width},${render.size.height}',
        );
      }
    }
    element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
}
