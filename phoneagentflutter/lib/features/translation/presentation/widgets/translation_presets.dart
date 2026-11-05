import 'package:flutter/material.dart';
import 'native_translation_preset_options.dart';
export 'native_translation_preset_options.dart'
    show TranslationOptions, NativeTranslationPresetSwitchRow;
import '../controller/translation_setup_controller.dart';
import '../pages/translation_selection_pages.dart';

Future<void> selectTranslationLanguage(
  BuildContext context,
  TranslationSetupController controller,
  bool caller,
  Set<String>? supportedLanguageCodes,
) async {
  if (!context.mounted ||
      ModalRoute.of(context)?.isCurrent != true ||
      !controller.mounted ||
      !controller.status.ready) {
    return;
  }
  final state = controller.snapshot;
  final code = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => TranslationLanguagePage(
        languages: controller.languages,
        caller: caller,
        selected: caller ? state.caller : state.peer,
        supportedLanguageCodes: supportedLanguageCodes,
      ),
    ),
  );
  if (context.mounted &&
      ModalRoute.of(context)?.isCurrent == true &&
      controller.mounted &&
      controller.status.ready &&
      code != null) {
    controller.language(
      code,
      caller: caller,
      supportedCodes: supportedLanguageCodes,
    );
  }
}

Future<bool> showTranslationPresets(
  BuildContext context,
  TranslationSetupController controller,
  ValueChanged<bool> onEnabled, {
  Set<String>? callerLanguageCodes,
  Set<String>? peerLanguageCodes,
}) async =>
    await showGeneralDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x52000000),
      transitionDuration: Theme.of(context).platform == TargetPlatform.iOS
          ? const Duration(milliseconds: 300)
          : Duration.zero,
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondary) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).top,
          ),
          child: Material(
            color: const Color(0xFFFCFCFD),
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: _PresetsBody(
              controller: controller,
              onEnabled: onEnabled,
              callerLanguageCodes: callerLanguageCodes,
              peerLanguageCodes: peerLanguageCodes,
            ),
          ),
        ),
      ),
    ) ??
    false;

class _PresetsBody extends StatefulWidget {
  const _PresetsBody({
    required this.controller,
    required this.onEnabled,
    this.callerLanguageCodes,
    this.peerLanguageCodes,
  });
  final TranslationSetupController controller;
  final ValueChanged<bool> onEnabled;
  final Set<String>? callerLanguageCodes, peerLanguageCodes;
  @override
  State<_PresetsBody> createState() => _PresetsBodyState();
}

class _PresetsBodyState extends State<_PresetsBody> {
  late final void Function() _unsubscribe;
  bool _finished = false;

  bool get _active =>
      mounted && !_finished && ModalRoute.of(context)?.isCurrent == true;
  bool get _editable =>
      _active && widget.controller.mounted && widget.controller.status.ready;

  void _finish(bool confirmed) {
    if (!_active || (confirmed && !_editable)) return;
    _finished = true;
    Navigator.pop(context, confirmed);
  }

  @override
  void initState() {
    super.initState();
    _unsubscribe = widget.controller.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.snapshot;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '实时翻译通话',
                      style: TextStyle(
                        color: Color(0xFF111318),
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(
                      Theme.of(context).platform == TargetPlatform.iOS ? 10 : 0,
                      0,
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        key: const ValueKey('translation-presets-close'),
                        tooltip: '关闭',
                        padding: EdgeInsets.zero,
                        onPressed: () => _finish(false),
                        icon: Theme.of(context).platform == TargetPlatform.iOS
                            ? const CustomPaint(
                                size: Size.square(20),
                                painter: _PresetCloseGlyph(),
                              )
                            : const Icon(
                                Icons.close,
                                size: 20,
                                color: Color(0xFF667085),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              TranslationOptions(
                state: state,
                onEnabled: (value) {
                  if (_editable) widget.onEnabled(value);
                },
                onPrompt: (value) {
                  if (_editable) widget.controller.prompt(value);
                },
                onLanguage: (caller) {
                  if (!_editable) return;
                  selectTranslationLanguage(
                    context,
                    widget.controller,
                    caller,
                    caller
                        ? widget.callerLanguageCodes
                        : widget.peerLanguageCodes,
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 54),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: state.enabled
                        ? const [Color(0xFF7C6DFF), Color(0xFF6C5CE7)]
                        : const [Color(0xFF34C759), Color(0xFF28A745)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: state.enabled
                          ? const Color(0x426C5CE7)
                          : const Color(0x3D34C759),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: () => _finish(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(0, 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    textStyle: TextStyle(
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.labelLarge?.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(state.enabled ? '实时翻译呼叫' : '普通呼叫'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCloseGlyph extends CustomPainter {
  const _PresetCloseGlyph();
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = const Color(0xFF667085)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 4), const Offset(16, 16), pen);
    canvas.drawLine(const Offset(16, 4), const Offset(4, 16), pen);
  }

  @override
  bool shouldRepaint(_PresetCloseGlyph oldDelegate) => false;
}
