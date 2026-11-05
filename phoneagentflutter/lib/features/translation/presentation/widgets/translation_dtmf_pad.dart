import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Presentation only. Sending and acknowledgement stay in the session owner.
class TranslationDtmfPad extends StatefulWidget {
  const TranslationDtmfPad({
    super.key,
    required this.enabled,
    required this.onDigit,
    this.enhanced = false,
  });
  final bool enabled, enhanced;
  final ValueChanged<String> onDigit;

  @override
  State<TranslationDtmfPad> createState() => _PadState();
}

class _PadState extends State<TranslationDtmfPad> {
  String _history = '';
  @override
  void didUpdateWidget(TranslationDtmfPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enhanced) _history = '';
  }

  void _input(String digit) {
    if (!mounted || !widget.enabled) return;
    if (widget.enhanced) {
      final value = '$_history$digit';
      setState(
        () => _history = value.substring(math.max(0, value.length - 32)),
      );
    }
    widget.onDigit(digit);
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = math.max(
      42.0,
      MediaQuery.textScalerOf(context).scale(21) * 1.3,
    );
    return FractionallySizedBox(
      widthFactor: .72,
      child: Material(
        color: const Color(0x66192B50),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.enhanced ? 6 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.enhanced) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _history.isEmpty ? '请输入按键' : _history,
                    key: const ValueKey('translation-dtmf-history'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: _history.isEmpty
                          ? const Color(0xFF8FA3C7)
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
              ],
              for (final row in ['123', '456', '789', '*0#']) ...[
                if (row != '123') const SizedBox(height: 1),
                SizedBox(
                  height: rowHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final digit in row.split(''))
                          _DtmfKey(
                            key: ValueKey('translation-key-state-$digit'),
                            digit: digit,
                            enabled: widget.enabled,
                            enhanced: widget.enhanced,
                            width: math.min(64, constraints.maxWidth / 3),
                            height: rowHeight,
                            onInput: _input,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DtmfKey extends StatefulWidget {
  const _DtmfKey({
    super.key,
    required this.digit,
    required this.enabled,
    required this.enhanced,
    required this.width,
    required this.height,
    required this.onInput,
  });
  final String digit;
  final bool enabled, enhanced;
  final double width, height;
  final ValueChanged<String> onInput;
  @override
  State<_DtmfKey> createState() => _KeyState();
}

class _KeyState extends State<_DtmfKey> {
  bool _pressed = false;
  void _press(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(_DtmfKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !widget.enhanced) _pressed = false;
  }

  void _input() {
    _press(false);
    if (widget.enabled) widget.onInput(widget.digit);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = widget.enabled && widget.enhanced && _pressed;
    final visual = Container(
      decoration: BoxDecoration(
        color: pressed ? const Color(0xFF2979FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.digit,
        style: const TextStyle(color: Colors.white, fontSize: 21),
      ),
    );
    return Semantics(
      key: ValueKey('translation-dtmf-${widget.digit}'),
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.digit,
      onTap: widget.enabled ? _input : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Listener(
            onPointerDown: widget.enabled && widget.enhanced
                ? (_) => _press(true)
                : null,
            onPointerUp: (_) => _press(false),
            onPointerCancel: (_) => _press(false),
            child: InkWell(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              onTap: widget.enabled ? _input : null,
              child: MediaQuery.disableAnimationsOf(context) || !widget.enhanced
                  ? Transform.scale(scale: pressed ? .88 : 1, child: visual)
                  : AnimatedScale(
                      scale: pressed ? .88 : 1,
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.fastOutSlowIn,
                      child: visual,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
