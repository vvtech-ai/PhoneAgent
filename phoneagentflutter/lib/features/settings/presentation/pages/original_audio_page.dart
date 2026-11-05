import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/settings_providers.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_page_header.dart';
import '../widgets/native_original_audio_controls.dart';

class OriginalAudioPage extends ConsumerWidget {
  const OriginalAudioPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(originalAudioControllerProvider);
    final controller = ref.read(originalAudioControllerProvider.notifier);
    final value = state.value;
    bool current() =>
        context.mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        controller.mounted &&
        identical(
          controller,
          ref.read(originalAudioControllerProvider.notifier),
        );
    bool editable({bool slider = false}) {
      if (!current()) return false;
      final latest = ref.read(originalAudioControllerProvider);
      return latest.ready && (!slider || latest.value.enabled);
    }

    void retry() {
      if (!current()) return;
      final latest = ref.read(originalAudioControllerProvider);
      if (latest.error.isEmpty || latest.loading || latest.saving) return;
      if (latest.ready) {
        controller.save();
      } else {
        controller.load();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: NativePageBackground(
        child: SafeArea(
          child: Column(
            children: [
              NativePageHeader(
                title: '实时翻译原音',
                onBack: () {
                  if (current()) Navigator.of(context).maybePop();
                },
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.error.isNotEmpty) ...[
                      Text(state.error, key: const Key('original-error')),
                      TextButton(
                        onPressed: retry,
                        child: Text(state.ready ? '重试保存' : '重新读取'),
                      ),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xCCFFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xC7FFFFFF)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '播放原声',
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 19 / 16,
                                          letterSpacing: 0,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        '开启后先播放通话原声；译音播放时按下方比例混合当前实时原声。',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 18 / 13,
                                          letterSpacing: 0,
                                          color: Color(0xFF6E6E73),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              NativeAudioToggle(
                                key: const Key('original-enabled'),
                                value: value.enabled,
                                onChanged: state.ready
                                    ? (v) {
                                        if (editable()) {
                                          controller.change(enabled: v);
                                        }
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          NativeAudioLevel(
                            label: '纯原声播放声音大小',
                            sliderKey: const Key('original-volume'),
                            value: value.volume,
                            max: 100,
                            onChanged: state.ready && value.enabled
                                ? (v) {
                                    if (editable(slider: true)) {
                                      controller.change(volume: v.round());
                                    }
                                  }
                                : null,
                          ),
                          NativeAudioLevel(
                            label: '混声时原声比例',
                            sliderKey: const Key('original-gain'),
                            value: value.gain,
                            max: 50,
                            onChanged: state.ready && value.enabled
                                ? (v) {
                                    if (editable(slider: true)) {
                                      controller.change(gain: v.round());
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '均按 10% 步进调节，仅影响下一通实时翻译通话。',
                            style: TextStyle(
                              fontSize: 12,
                              height: 18 / 12,
                              letterSpacing: 0,
                              color: Color(0xFF6E6E73),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.saving) ...[
                      const SizedBox(height: 16),
                      const Text('保存中…', style: ShellTokens.subtitle),
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
}
