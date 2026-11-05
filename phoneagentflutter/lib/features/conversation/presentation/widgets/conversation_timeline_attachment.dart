import 'package:flutter/widgets.dart';

/// UI insertion boundary; attachment controllers retain their own async state.
class ConversationTimelineAttachment {
  const ConversationTimelineAttachment(this.id, this.anchor, this.child);
  final String id;
  final int anchor;
  final Widget child;
}

List<Widget> withTimelineAttachments(
  List<Widget> messages,
  List<ConversationTimelineAttachment> attachments,
) => [
  for (var boundary = 0; boundary <= messages.length; boundary++) ...[
    for (final attachment in attachments)
      if (attachment.anchor.clamp(0, messages.length) == boundary)
        KeyedSubtree(
          key: ValueKey('attachment:${attachment.id}'),
          child: attachment.child,
        ),
    if (boundary < messages.length) messages[boundary],
  ],
];
