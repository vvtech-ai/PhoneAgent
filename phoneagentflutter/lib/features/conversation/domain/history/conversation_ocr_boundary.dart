import '../conversation_messages.dart';
import 'conversation_source_steps.dart';
import 'ledger_event.dart';

class ConversationOcrBoundary {
  const ConversationOcrBoundary._(this.sourceAnchor, this._displayBoundaries);
  final int sourceAnchor;
  final List<int> _displayBoundaries;
  int displayBoundaryFor(int sourceAnchor) =>
      _displayBoundaries[sourceAnchor.clamp(0, _displayBoundaries.length - 1)];

  factory ConversationOcrBoundary.project(
    Iterable<LedgerEvent> facts,
    List<ConversationMessage> visible,
  ) {
    final source = ConversationSourceSteps.project(facts).toList();
    final positions = {
      for (var i = 0; i < visible.length; i++) visible[i].id: i,
    };
    int position(ConversationSourceStep step) => step.aliases
        .map((id) => positions[id] ?? -1)
        .fold(-1, (a, b) => a > b ? a : b);
    // Live uncommitted messages occupy their actual visible turn position.
    // Once committed, their durable source identity replaces the overlay.
    for (var i = 0; i < visible.length; i++) {
      final message = visible[i];
      if (!message.transient) continue;
      final next = source.indexWhere((step) => position(step) > i);
      source.insert(
        next < 0 ? source.length : next,
        ConversationSourceStep(message.id, 0, 0, {message.id}),
      );
    }
    // The first OCR upload may persist the opening after its zero anchor was
    // captured. Keep that stored anchor, but display it after the known opening.
    final openingIds = {
      for (final event in facts)
        if (event.schemaVersion == 1 &&
            event.type == 'ASSISTANT_TURN_COMMITTED' &&
            event.commandId == 'initial-opening:${event.sessionId}')
          'ledger:${event.eventId}',
    };
    final openingBoundary = visible
        .takeWhile(
          (message) =>
              message.role == MessageRole.assistant &&
              openingIds.contains(message.id),
        )
        .length;
    final boundaries = <int>[openingBoundary];
    var sourceAnchor = 0, display = openingBoundary;
    for (var i = 0; i < source.length; i++) {
      final step = source[i], after = position(source[i]) + 1;
      if (after > display) display = after;
      boundaries.add(display);
      if (step.contributes) sourceAnchor = i + 1;
    }
    return ConversationOcrBoundary._(
      sourceAnchor,
      List.unmodifiable(boundaries),
    );
  }
}
