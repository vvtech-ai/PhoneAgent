import '../../../../core/design/native_notice.dart';
import '../../../../core/design/native_system_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart';
import '../../../../app/invite_providers.dart';
import '../../../../core/design/native_page_header.dart';
import '../widgets/invite_activity_card.dart'
    show InvitePrimaryAction, inviteBlue;
import '../widgets/invite_poster.dart';
import '../widgets/invite_single_line_text.dart';

/// v67 poster page shared by the welfare and settings invitation entries.
class InvitePage extends ConsumerWidget {
  const InvitePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inviteControllerProvider);
    final controller = ref.read(inviteControllerProvider.notifier);
    final activity = state.overview?.activity;
    final code = state.code;
    ref.listen(inviteControllerProvider.select((s) => s.notice), (_, notice) {
      if (notice.isNotEmpty &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent != false) {
        showNativeNotice(context, notice);
      }
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NativeSystemChrome.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, .52, 1],
              colors: [Color(0xFF0E7CF0), Color(0xFF355EDB), Color(0xFF6555DF)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                NativePageHeader(
                  title: '邀请好友',
                  foregroundColor: Colors.white,
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/invite_brand_white.png',
                            width: 40,
                            height: 40,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Phone Agent',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      if (code != null && activity != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 19,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '我的邀请码',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              InviteSingleLineText(
                                invitePosterRewardText(state.overview!),
                                alignment: Alignment.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C828B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                label: '邀请链接二维码',
                                image: true,
                                child: SizedBox(
                                  width: 184,
                                  height: 184,
                                  child: CustomPaint(
                                    painter: InviteQrPainter(code.url),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Semantics(
                                container: true,
                                child: SelectableText(
                                  code.code,
                                  semanticsLabel: code.code,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 29,
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InviteSingleLineText(
                                inviteActivityDeadline(activity),
                                alignment: Alignment.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 3),
                              InviteSingleLineText(
                                '同一邀请码最多可邀请${activity.quota}位新用户',
                                alignment: Alignment.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 13),
                        InvitePrimaryAction(
                          label: state.actionType == 'SAVE_POSTER'
                              ? '保存中…'
                              : '保存图片',
                          background: Colors.white,
                          foreground: inviteBlue,
                          onPressed: controller.canShare
                              ? () => controller.savePoster(
                                  code,
                                  InvitePosterPainter(activity, code).render,
                                )
                              : null,
                        ),
                        const SizedBox(height: 9),
                        TextButton(
                          onPressed: controller.canShare
                              ? () => controller.copy(true)
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            textStyle: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          child: const Text('复制链接'),
                        ),
                        if (!controller.canShare && !state.acting)
                          const Text(
                            '当前邀请不可分享，请返回刷新或查看活动状态',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                      ] else
                        Text(
                          state.error.isEmpty ? '邀请码暂不可用，请返回刷新' : state.error,
                          style: const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InviteQrPainter extends CustomPainter {
  InviteQrPainter(String url)
    : qr = QrImage(
        QrCode.fromData(data: url, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
  final QrImage qr;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final unit = size.shortestSide / (qr.moduleCount + 8);
    final ink = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var r = 0; r < qr.moduleCount; r++) {
      for (var c = 0; c < qr.moduleCount; c++) {
        if (qr.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH((c + 4) * unit, (r + 4) * unit, unit, unit),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(InviteQrPainter old) => old.qr != qr;
}
