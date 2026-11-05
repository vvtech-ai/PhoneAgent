import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/contact_providers.dart';
import '../widgets/contact_skills_sheet.dart';
import '../../../home/domain/home_config.dart';
import '../../domain/contact_records.dart';
import '../../domain/contact_skill_opening.dart';
import '../../../conversation/domain/agent_protocol.dart';
import '../../../conversation/presentation/controller/conversation_controller.dart';
import '../../../conversation/presentation/controller/conversation_state.dart';
import 'contact_task_route.dart';
import '../../../settings/presentation/widgets/online_entry_guard.dart';
import '../../../dialer/presentation/pages/dialer_route.dart';
import '../../../conversation/presentation/widgets/task_entry_permission_guard.dart';

Future<void> showContactDial(
  BuildContext context,
  ContactRecord contact, {
  required bool preview,
}) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  if (preview) {
    showNativeNotice(
      context,
      'MOCK · 系统拨号交接演练，未拨号。',
      duration: const Duration(seconds: 4),
    );
    return;
  }
  final route = ModalRoute.of(context);
  final controller = ProviderScope.containerOf(
    context,
  ).read(contactSystemDialControllerProvider.notifier);
  final message = await controller.open(
    contact.systemDialPhone.trim().isEmpty
        ? contact.phone
        : contact.systemDialPhone,
  );
  if (!context.mounted ||
      route?.isCurrent != true ||
      message == null ||
      message.isEmpty) {
    return;
  }
  showNativeNotice(context, message, duration: const Duration(seconds: 4));
}

Future<void> showContactSkills(
  BuildContext context,
  ContactRecord contact, {
  required bool preview,
}) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  final container = ProviderScope.containerOf(context);
  final origin = ModalRoute.of(context);
  final epoch = preview ? null : container.read(loginEpochProvider);
  bool current() =>
      origin?.isCurrent == true &&
      (preview || container.read(loginEpochProvider) == epoch);
  final skill = await showModalBottomSheet<HomeCard>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFBFCFF),
    barrierColor: const Color(0x6B111827),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _SkillsSheet(contact: contact, preview: preview),
    ),
  );
  if (skill == null || !context.mounted || !current()) {
    return;
  }
  if (!await allowOnlineEntry(context) || !context.mounted || !current()) {
    return;
  }
  if (!preview &&
      (!await allowTaskMicrophoneEntry(context, current) ||
          !context.mounted ||
          !current())) {
    return;
  }
  if (skill.action == HomeAction.translation) {
    await openDialer(
      context,
      number: contact.phone,
      name: contact.name,
      preview: preview,
      translationEntry: true,
    );
    return;
  }
  final entry = ConversationEntry(
    sessionId: newConversationId(),
    title: skill.title,
    skillId: skill.skillId,
    opening: contactSkillOpening(
      skill.skillId!,
      contact.name,
      skill.opening,
      template: skill.selectedContactOpening,
    ),
    selectedContact: SelectedContactContext(
      name: contact.name,
      phone: contact.phone,
    ),
    ownerEpoch: epoch,
  );
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: ContactTaskRoute(entry: entry, preview: preview),
      ),
    ),
  );
}

class _SkillsSheet extends ConsumerStatefulWidget {
  const _SkillsSheet({required this.contact, required this.preview});
  final ContactRecord contact;
  final bool preview;
  @override
  ConsumerState<_SkillsSheet> createState() => _SkillsSheetState();
}

class _SkillsSheetState extends ConsumerState<_SkillsSheet> {
  bool _finished = false;

  void _finish([HomeCard? card]) {
    if (!mounted || _finished || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _finished = true;
    Navigator.pop(context, card);
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(contactSkillsControllerProvider);
    return ContactSkillsSheet(
      contactName: widget.contact.name,
      cards: skills.cards,
      loading: skills.loading,
      error: skills.error,
      onRetry: () {
        if (mounted &&
            !_finished &&
            ModalRoute.of(context)?.isCurrent == true) {
          ref.read(contactSkillsControllerProvider.notifier).load();
        }
      },
      preview: widget.preview,
      onClose: _finish,
      onSelect: _finish,
    );
  }
}
