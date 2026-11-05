import 'package:flutter/material.dart';
import '../../../identity/presentation/widgets/identity_widgets.dart';
import '../controller/initialization_controller.dart';
import '../widgets/initialization_fields.dart';
import '../widgets/initialization_header.dart';

class InitializationPage extends StatelessWidget {
  const InitializationPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
    required this.onRetry,
    required this.onName,
    required this.onGender,
    required this.onPhone,
    required this.onModel,
    this.previewHeader,
  });
  final InitializationState state;
  final VoidCallback onBack, onSkip, onNext, onRetry;
  final ValueChanged<String> onName, onGender, onPhone, onModel;
  final Widget? previewHeader;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        if (previewHeader != null) previewHeader!,
        InitializationHeader(
          showBack: state.step > 1,
          showSkip: state.step == 1 && state.ready,
          busy: state.busy,
          onBack: onBack,
          onSkip: onSkip,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: _body(context),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (state.ready)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: SizedBox(
              width: double.infinity,
              child: IdentityAction(
                label: state.saving
                    ? '保存中…'
                    : state.step < 2
                    ? '下一步'
                    : '完成',
                onTap:
                    state.busy ||
                        (state.step == 1 && state.draft.name.trim().isEmpty)
                    ? null
                    : onNext,
              ),
            ),
          ),
      ],
    ),
  );
  Widget _body(BuildContext context) {
    if (state.loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载初始化资料'),
        ],
      );
    }
    if (!state.ready) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.error.isEmpty ? '正在准备初始化' : state.error),
          TextButton(onPressed: onRetry, child: const Text('重试加载')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.step == 1 ? '身份信息' : '通话语音模型',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          state.step == 1 ? '设置身份信息以便Agent更好的进行沟通' : '选择AI 外呼通话模型',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 30),
        if (state.step == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: InitializationIdentityFields(
              draft: state.draft,
              busy: state.busy,
              onName: onName,
              onGender: onGender,
              onPhone: onPhone,
            ),
          )
        else
          InitializationModelCards(
            catalog: state.calls!,
            selected: state.callModel,
            busy: state.busy,
            onSelect: onModel,
          ),
        if (state.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              state.error,
              style: const TextStyle(color: IdentityStyle.danger),
            ),
          ),
      ],
    );
  }
}
