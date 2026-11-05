import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/design/attachment_tokens.dart';

enum AttachmentChoice { album, document }

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({
    super.key,
    required this.onChoose,
    required this.onClose,
  });
  final ValueChanged<AttachmentChoice> onChoose;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: AttachmentTokens.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8DEE8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  '添加内容',
                  style: AttachmentTokens.heading,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: '关闭添加内容',
                onPressed: onClose,
                icon: SvgPicture.asset(
                  'assets/images/shell/dial_close.svg',
                  width: 20,
                  height: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row(
            '相册',
            '识别图片中的联系方式和文字',
            AttachmentChoice.album,
            SvgPicture.asset(
              'assets/images/conversation/attachment_album.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                AttachmentTokens.accent,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _row(
            '文档',
            '导入 Word 或 Excel 资料',
            AttachmentChoice.document,
            const Icon(
              Icons.description_rounded,
              size: 22,
              color: AttachmentTokens.accent,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _row(
    String title,
    String subtitle,
    AttachmentChoice choice,
    Widget icon,
  ) => Material(
    color: AttachmentTokens.row,
    borderRadius: BorderRadius.circular(AttachmentTokens.rowRadius),
    child: InkWell(
      onTap: () => onChoose(choice),
      borderRadius: BorderRadius.circular(AttachmentTokens.rowRadius),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AttachmentTokens.iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AttachmentTokens.title),
                  Text(subtitle, style: AttachmentTokens.subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
