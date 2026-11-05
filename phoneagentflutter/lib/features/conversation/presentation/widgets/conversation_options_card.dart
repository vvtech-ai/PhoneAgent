import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../domain/conversation_messages.dart';
import 'conversation_option_content.dart';
import 'conversation_option_values.dart';

class ConversationOptionsCard extends StatefulWidget {
  const ConversationOptionsCard({
    super.key,
    required this.message,
    required this.enabled,
    required this.onSelect,
  });
  final ConversationMessage message;
  final bool enabled;
  final bool Function(int) onSelect;
  @override
  State<ConversationOptionsCard> createState() => _OptionsCardState();
}

class _OptionsCardState extends State<ConversationOptionsCard> {
  int? _selected;
  late List<Object?> _values;
  bool _highlighted(int index) =>
      _selected == index &&
      (!widget.message.optionsLocked ||
          widget.message.id.startsWith('local:apology:'));
  @override
  void initState() {
    super.initState();
    _values = conversationOptionValues(widget.message);
    _selected = widget.message.selectedOptionIndex;
  }

  @override
  void didUpdateWidget(ConversationOptionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final values = conversationOptionValues(widget.message);
    if (oldWidget.message.id != widget.message.id ||
        !listEquals(_values, values) ||
        oldWidget.message.selectedOptionIndex !=
            widget.message.selectedOptionIndex ||
        oldWidget.message.optionsLocked != widget.message.optionsLocked ||
        (!oldWidget.enabled && widget.enabled)) {
      _selected = widget.message.selectedOptionIndex;
    }
    _values = values;
  }

  void _select(int index) {
    if (!widget.enabled || widget.message.optionsLocked || _selected != null) {
      return;
    }
    if (widget.onSelect(index) && mounted) setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      key: ValueKey('message:${widget.message.id}'),
      constraints: BoxConstraints(
        maxWidth: widget.message.optionsTitleVisible ? 284 : 260,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        elevation: 2,
        color: widget.message.optionsLocked
            ? const Color(0xFFF3F4F6)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x99000000),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message.optionsTitleVisible &&
                widget.message.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
                child: Text(
                  widget.message.text,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    height: 24 / 15,
                    color: widget.message.optionsLocked
                        ? const Color(0xFF667085)
                        : const Color(0xFF1D2939),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  for (final (index, option)
                      in widget.message.options.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    Semantics(
                      selected: _selected == index,
                      button: true,
                      label: '${index + 1}. ${option.label}',
                      child: Opacity(
                        opacity:
                            (widget.message.optionsLocked &&
                                    !_highlighted(index)) ||
                                ((!widget.enabled || _selected != null) &&
                                    _selected != index)
                            ? .58
                            : 1,
                        child: Material(
                          color: _highlighted(index)
                              ? const Color(0xFFEAF3FF)
                              : widget.message.optionsLocked
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                            side: BorderSide(
                              color: _highlighted(index)
                                  ? const Color(0xFF087FF5)
                                  : widget.message.optionsLocked
                                  ? const Color(0xFFB8C1CC)
                                  : const Color(0xFFDBE4F0),
                            ),
                          ),
                          child: InkWell(
                            key: ValueKey('option:${widget.message.id}:$index'),
                            onTap:
                                widget.enabled &&
                                    !widget.message.optionsLocked &&
                                    _selected == null
                                ? () => _select(index)
                                : null,
                            borderRadius: BorderRadius.circular(13),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 8,
                                ),
                                child: ConversationOptionContent(
                                  index: index,
                                  option: option,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
