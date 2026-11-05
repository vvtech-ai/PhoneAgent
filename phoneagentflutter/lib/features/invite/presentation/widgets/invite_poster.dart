import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import '../../domain/invite.dart';

String inviteActivityDeadline(InviteActivity activity) {
  if (activity.longTerm) return '活动截止日期：长期有效';
  final date = DateTime.tryParse(
    activity.endAt,
  )?.toUtc().add(const Duration(hours: 8));
  if (date == null) {
    return activity.endAt.isEmpty ? '' : '活动截止日期：${activity.endAt}';
  }
  return '活动截止日期：${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
}

String invitePosterRewardText(InviteOverview overview) {
  final personal = overview.personal;
  final inviter = personal?.eligible == true && personal!.inviterPoints > 0
      ? '你获得${personal.inviterPoints}积分'
      : overview.inviterLabel;
  return '好友完成有效注册，$inviter，好友获得${overview.activity!.inviteePoints}积分';
}

/// Shared native 900×1240 saved poster. QR includes a four-module quiet zone.
class InvitePosterPainter extends CustomPainter {
  InvitePosterPainter(this.activity, this.code)
    : qr = QrImage(
        QrCode.fromData(
          data: code.url,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
  final InviteActivity activity;
  final InviteCode code;
  final QrImage qr;
  ui.Image? _brand;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 900, size.height / 1240);
    const bounds = Rect.fromLTWH(0, 0, 900, 1240);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, .52, 1],
          colors: [Color(0xFF0E7CF0), Color(0xFF355EDB), Color(0xFF6555DF)],
        ).createShader(bounds),
    );
    if (_brand != null) {
      canvas.drawImageRect(
        _brand!,
        Rect.fromLTWH(
          0,
          0,
          _brand!.width.toDouble(),
          _brand!.height.toDouble(),
        ),
        const Rect.fromLTWH(226, 64, 80, 80),
        Paint(),
      );
    }
    void text(
      String value,
      double top,
      double font, {
      Color color = const Color(0xFF1B2333),
      bool bold = false,
      double? left,
      double maxWidth = 730,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: font,
            color: color,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(left ?? (900 - painter.width) / 2, top));
    }

    text(
      'Phone Agent',
      78,
      48,
      color: Colors.white,
      bold: true,
      left: 330,
      maxWidth: 500,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 194, 784, 886),
        const Radius.circular(60),
      ),
      Paint()..color = Colors.white,
    );
    text('我的邀请码', 220, 48, bold: true);
    const area = 600.0;
    final unit = (area / (qr.moduleCount + 8)).floorToDouble();
    final extent = unit * (qr.moduleCount + 8);
    final left = 150 + (area - extent) / 2 + 4 * unit;
    final top = 290 + (area - extent) / 2 + 4 * unit;
    final ink = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var col = 0; col < qr.moduleCount; col++) {
        if (qr.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(left + col * unit, top + row * unit, unit, unit),
            ink,
          );
        }
      }
    }
    text(code.code, 908, 78, bold: true);
    text(
      '同一邀请码最多可邀请${activity.quota}位新用户',
      1005,
      23,
      color: const Color(0xFF9A9FA7),
    );
    text(inviteActivityDeadline(activity), 1130, 25, color: Colors.white);
    canvas.restore();
  }

  Future<Uint8List> render() async {
    final data = await rootBundle.load('assets/images/invite_brand_white.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    _brand = frame.image;
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), const Size(900, 1240));
    final picture = recorder.endRecording();
    final image = await picture.toImage(900, 1240);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Unable to encode poster');
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
      _brand!.dispose();
      _brand = null;
    }
  }

  @override
  bool shouldRepaint(InvitePosterPainter old) =>
      old.code != code || old.activity != activity;
}
