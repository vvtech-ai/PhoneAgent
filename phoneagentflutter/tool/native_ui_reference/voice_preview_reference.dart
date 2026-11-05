import 'package:flutter/material.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';

/// Production controls with local visual states only; no media or accounts.
void main() => runApp(const MaterialApp(home: _Reference()));

class _Reference extends StatefulWidget {
  const _Reference();
  @override
  State<_Reference> createState() => _ReferenceState();
}

class _ReferenceState extends State<_Reference> {
  int _state = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('试听按钮 · 合成状态，无音频')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('首行点击依次切换加载 / 播放 / 默认；不产生音频。'),
        NativeVoiceSelectionRow(
          voice: const CallVoice('__CLONE__', '我的克隆音色', '', false),
          selected: true,
          enabled: true,
          onSelect: () {},
          showPreview: true,
          previewLoading: _state == 1,
          previewPlaying: _state == 2,
          onPreview: () => setState(() => _state = (_state + 1) % 3),
        ),
        for (final name in ['Andre', 'Ethan', 'Katerina'])
          NativeVoiceSelectionRow(
            voice: CallVoice(name, name, '系统音色 · 合成状态', false),
            selected: false,
            enabled: true,
            onSelect: () {},
            showPreview: true,
            onPreview: () => setState(() => _state = (_state + 1) % 3),
          ),
        for (final state in ['loading', 'playing', 'disabled'])
          NativeVoiceSelectionRow(
            voice: CallVoice(state, state, '固定状态', false),
            selected: false,
            enabled: true,
            onSelect: () {},
            showPreview: true,
            previewLoading: state == 'loading',
            previewPlaying: state == 'playing',
            onPreview: state == 'disabled' ? null : () {},
          ),
      ],
    ),
  );
}
