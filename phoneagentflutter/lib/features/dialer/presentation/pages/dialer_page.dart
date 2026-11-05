import '../widgets/native_dial_pad.dart';
import 'package:flutter/material.dart';
import '../widgets/dialer_bottom_actions.dart';
import '../widgets/native_dial_number_header.dart';
import '../controller/dialer_controller.dart';

class DialerPage extends StatelessWidget {
  const DialerPage({
    super.key,
    required this.state,
    required this.onCountry,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.onDial,
    required this.onClose,
    this.onPreview,
    this.configuration,
    this.bottomNote,
    this.suggestions,
    this.dialLabel = '拨号',
    this.translationEnabled = false,
  });
  final DialerState state;
  final VoidCallback onCountry, onDelete, onClear, onDial, onClose;
  final VoidCallback? onPreview;
  final Widget? configuration;
  final Widget? bottomNote;
  final Widget? suggestions;
  final String dialLabel;
  final bool translationEnabled;
  final ValueChanged<String> onDigit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ColoredBox(
        color: const Color(0xFFF8F9FC),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final header = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.preview)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'MOCK · 拨号交互演练，不会拨出电话',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF986300),
                              ),
                            ),
                          ),
                        NativeDialNumberHeader(
                          country: state.country,
                          input: state.input,
                          onCountry: state.busy ? null : onCountry,
                        ),
                        if (onPreview != null)
                          TextButton(
                            onPressed: onPreview,
                            child: const Text('进入拨号交互演练（MOCK）'),
                          ),
                      ],
                    );
                    final notice = state.message.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                state.message,
                                key: const Key('dial-message'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFB53B17),
                                ),
                              ),
                            ),
                          );
                    final tail = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        notice,
                        if (configuration != null) configuration!,
                        NativeDialPad(onDigit: state.busy ? null : onDigit),
                      ],
                    );
                    final compact =
                        state.preview ||
                        onPreview != null ||
                        MediaQuery.textScalerOf(context).scale(24) > 36 ||
                        constraints.maxHeight < 600;
                    if (compact) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  header,
                                  const SizedBox(height: 24),
                                  if (suggestions != null) suggestions!,
                                ],
                              ),
                              tail,
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        header,
                        const SizedBox(height: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: suggestions ?? const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        tail,
                      ],
                    );
                  },
                ),
              ),
            ),
            DialerBottomActions(
              busy: state.busy,
              hasInput: state.input.isNotEmpty,
              translationEnabled: translationEnabled,
              dialLabel: dialLabel,
              onClose: onClose,
              onDial: onDial,
              onDelete: onDelete,
              onClear: onClear,
              note: bottomNote,
            ),
          ],
        ),
      ),
    ),
  );
}
