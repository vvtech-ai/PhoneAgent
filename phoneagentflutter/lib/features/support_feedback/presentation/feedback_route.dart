import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/support_feedback_providers.dart';
import 'feedback_page.dart';

class FeedbackRoute extends ConsumerWidget {
  const FeedbackRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(loginEpochProvider);
    final state = ref.watch(supportFeedbackProvider);
    final controller = ref.read(supportFeedbackProvider.notifier);
    bool current() =>
        context.mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        identical(controller, ref.read(supportFeedbackProvider.notifier));
    return FeedbackPage(
      key: ValueKey(epoch),
      state: state,
      onDescription: (value) {
        if (current()) controller.edit(description: value);
      },
      onContact: (value) {
        if (current()) controller.edit(contact: value);
      },
      onLogs: (value) {
        if (current()) controller.edit(includeLogs: value);
      },
      onAdd: () {
        if (current()) {
          controller.addImages(ref.read(feedbackImagePickerProvider).pick);
        }
      },
      onRemove: (index) {
        if (current()) controller.removeImage(index);
      },
      onSubmit: () {
        if (current()) controller.submit();
      },
    );
  }
}
