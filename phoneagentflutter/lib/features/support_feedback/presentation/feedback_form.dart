import 'package:flutter/material.dart';
import '../../../core/design/native_action_style.dart';
import '../../../../core/design/shell_tokens.dart';
import 'feedback_images.dart';
import 'feedback_state.dart';

class FeedbackForm extends StatelessWidget {
  const FeedbackForm({
    super.key,
    required this.state,
    required this.onDescription,
    required this.onContact,
    required this.onLogs,
    required this.onAdd,
    required this.onRemove,
    required this.onSubmit,
  });
  final FeedbackState state;
  final ValueChanged<String> onDescription, onContact;
  final ValueChanged<bool> onLogs;
  final VoidCallback onAdd, onSubmit;
  final ValueChanged<int> onRemove;
  static const _hintStyle = TextStyle(
    color: Color(0xFF75757E),
    fontSize: 12,
    height: 1.6,
  );
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('问题描述'),
        TextFormField(
          key: const Key('feedback-description'),
          initialValue: state.description,
          enabled: !state.busy,
          minLines: 5,
          maxLines: 8,
          style: const TextStyle(fontSize: 15, height: 1.6),
          onChanged: onDescription,
          decoration: _decoration('请描述你遇到的问题或建议'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${state.description.runes.length}/2000',
            style: _hintStyle,
          ),
        ),
        const SizedBox(height: 18),
        _label('相关图片', optional: true),
        FeedbackImages(
          images: state.images,
          busy: state.busy,
          onAdd: onAdd,
          onRemove: onRemove,
        ),
        const SizedBox(height: 8),
        const Text(
          '最多6张，单张原图不超过10 MB；超过2 MB的图片自动压缩至2 MB以内。',
          style: _hintStyle,
        ),
        const SizedBox(height: 24),
        _label('联系方式', optional: true),
        TextFormField(
          key: const Key('feedback-contact'),
          initialValue: state.contact,
          enabled: !state.busy,
          onChanged: onContact,
          style: const TextStyle(fontSize: 15, height: 1.6),
          decoration: _decoration('手机号 / 微信 ID / 邮箱'),
        ),
        const SizedBox(height: 8),
        const Text('方便我们联系你，进一步了解问题', style: _hintStyle),
        const SizedBox(height: 24),
        Semantics(
          checked: state.includeLogs,
          label: '附带诊断日志',
          child: InkWell(
            key: const Key('feedback-logs'),
            onTap: state.busy ? null : () => onLogs(!state.includeLogs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox.square(
                    dimension: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: state.includeLogs
                            ? ShellTokens.accent
                            : Colors.white,
                        border: Border.all(
                          color: state.includeLogs
                              ? ShellTokens.accent
                              : const Color(0xFFBCBCC7),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: state.includeLogs
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '附带诊断日志',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text('帮助我们排查问题，仅在勾选后随反馈提交', style: _hintStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (state.processing) const Text('正在处理图片…', style: _hintStyle),
        if (state.error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              state.error,
              key: const Key('feedback-error'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFB23546),
              ),
            ),
          ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: NativeActionStyle.decoration(enabled: !state.busy),
          child: FilledButton(
            key: const Key('feedback-submit'),
            onPressed: state.busy ? null : onSubmit,
            style: NativeActionStyle.buttonStyle(context),
            child: Text(state.busy && !state.processing ? '提交中…' : '提交反馈'),
          ),
        ),
      ],
    ),
  );

  Widget _label(String text, {bool optional = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        children: optional
            ? [
                const TextSpan(
                  text: '（选填）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF767680),
                  ),
                ),
              ]
            : [],
      ),
    ),
  );
  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF777782)),
    filled: true,
    fillColor: const Color(0xFFF5F5F8),
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}
