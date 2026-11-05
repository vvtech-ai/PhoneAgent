import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

class FlutterContactsSkillsReference extends StatelessWidget {
  const FlutterContactsSkillsReference({super.key, required this.scene});
  final String scene;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
      child: ColoredBox(
        color: const Color(0x6B111827),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: const Color(0xFFFBFCFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ContactSkillsSheet(
                contactName: '合成联系人',
                cards: scene == 'contacts-skills'
                    ? const [
                        HomeCard(
                          id: '1',
                          title: '合成叫醒服务',
                          subtitle: '请在指定时间联系此人',
                          status: HomeCardStatus.enabled,
                          action: HomeAction.skill,
                          skillId: '1',
                        ),
                        HomeCard(
                          id: '2',
                          title: '合成用于长标题省略核对的技能',
                          subtitle: '合成较长的技能说明用于核对正常与放大字号下的两行省略和列表显示效果。',
                          status: HomeCardStatus.enabled,
                          action: HomeAction.skill,
                          skillId: '2',
                        ),
                      ]
                    : const [],
                loading: scene == 'contacts-skills-loading',
                preview: false,
                onClose: () {},
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
