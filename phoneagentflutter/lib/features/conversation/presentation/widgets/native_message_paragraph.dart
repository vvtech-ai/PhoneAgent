import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Only platform text layout/rendering. Never reads business or device state.
class NativeMessageParagraph extends StatefulWidget {
  const NativeMessageParagraph({
    super.key,
    required this.text,
    required this.style,
    this.useNative,
    this.nativeViewBuilder,
  });
  final String text;
  final TextStyle style;
  @visibleForTesting
  final bool? useNative;
  @visibleForTesting
  final Widget Function(Map<String, Object?>)? nativeViewBuilder;

  @override
  State<NativeMessageParagraph> createState() => _ParagraphState();
}

typedef _LayoutKey = (String, double, double, double, int, TextDirection);

class _ParagraphState extends State<NativeMessageParagraph> {
  static const _channel = MethodChannel('phone_agent/native_paragraph');
  _LayoutKey? _requested, _ready;
  Size? _size;
  int _epoch = 0, _viewRevision = 0;
  MethodChannel? _viewChannel;

  bool get _native =>
      widget.useNative ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _epoch++;
    _viewChannel = null;
    super.dispose();
  }

  Map<String, Object?> _arguments(_LayoutKey key) => {
    'text': key.$1,
    'maxWidth': key.$2,
    'fontSize': key.$3,
    'lineHeight': key.$4,
    'color': key.$5,
    'direction': key.$6 == TextDirection.rtl ? 'rtl' : 'ltr',
  };

  void _failed(int epoch) {
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _ready = null;
      _size = null;
      _viewChannel = null;
    });
  }

  Future<void> _updateView(_LayoutKey key) async {
    final channel = _viewChannel;
    if (channel == null) return;
    final epoch = _epoch;
    try {
      await channel.invokeMethod<void>('update', {
        ..._arguments(key),
        'revision': ++_viewRevision,
      });
    } on PlatformException {
      if (identical(channel, _viewChannel)) _failed(epoch);
    } on MissingPluginException {
      if (identical(channel, _viewChannel)) _failed(epoch);
    }
  }

  void _viewCreated(int id) {
    if (!mounted || _ready == null) return;
    _viewChannel = MethodChannel('phone_agent/native_paragraph/view/$id');
    _viewRevision = 0;
    unawaited(_updateView(_ready!));
  }

  void _schedule(_LayoutKey key) {
    if (_requested == key) return;
    _requested = key;
    final epoch = ++_epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || epoch != _epoch) return;
      try {
        final value = await _channel.invokeMapMethod<String, Object?>(
          'measure',
          _arguments(key),
        );
        if (!mounted || epoch != _epoch || !_native) return;
        final width = value?['width'], height = value?['height'];
        if (width is! num ||
            height is! num ||
            !width.isFinite ||
            !height.isFinite ||
            width <= 0 ||
            width > key.$2 ||
            height < key.$4) {
          _failed(epoch);
          return;
        }
        setState(() {
          _ready = key;
          _size = Size(width.toDouble(), height.toDouble());
        });
        unawaited(_updateView(key));
      } on PlatformException {
        _failed(epoch);
        // Keep the readable Flutter renderer. Never fabricate native parity.
      } on MissingPluginException {
        _failed(epoch);
        // Plain Flutter hosts and unsupported builds retain the fallback.
      }
    });
  }

  Widget _fallback(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(
          text: widget.text,
          style: DefaultTextStyle.of(context).style.merge(widget.style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        textWidthBasis: TextWidthBasis.longestLine,
      )..layout(maxWidth: constraints.maxWidth);
      // SelectableText needs a small edge allowance beyond TextPainter’s
      // exact width; otherwise short selectable lines can wrap.
      final width = (painter.width.ceilToDouble() + 4).clamp(
        0.0,
        constraints.maxWidth,
      );
      painter.dispose();
      return SizedBox(
        width: width,
        child: SelectableText(widget.text, style: widget.style),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    if (!_native) {
      _epoch++;
      _requested = _ready = null;
      _size = null;
      _viewChannel = null;
      return _fallback(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = widget.style.fontSize ?? 14;
        final scaled = MediaQuery.textScalerOf(context).scale(size);
        final key = (
          widget.text,
          constraints.maxWidth,
          scaled,
          scaled * (widget.style.height ?? 22 / 14),
          (widget.style.color ?? const Color(0xFF1A1A1A)).toARGB32(),
          Directionality.of(context),
        );
        if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
          _schedule(key);
        }
        if (_ready == null || _size == null) {
          return _fallback(context);
        }
        // Keep the current native view while a new layout is being measured.
        final args = _arguments(_ready!);
        return SizedBox(
          width: _size!.width,
          height: _size!.height,
          child:
              widget.nativeViewBuilder?.call(args) ??
              UiKitView(
                key: const ValueKey('native-message-text-view'),
                onPlatformViewCreated: _viewCreated,
                viewType: 'phone_agent/native_paragraph/view',
                creationParams: args,
                creationParamsCodec: const StandardMessageCodec(),
                layoutDirection: key.$6,
              ),
        );
      },
    );
  }
}
