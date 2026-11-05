import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/clone_enrollment.dart';
import '../controller/clone_enrollment_controller.dart';
import 'native_clone_controls.dart';
export 'clone_processing_step.dart';

class CloneConsentStep extends StatelessWidget {
  const CloneConsentStep({
    super.key,
    required this.state,
    required this.onAgree,
    required this.onNext,
  });
  final CloneEnrollmentState state;
  final ValueChanged<bool> onAgree;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: cloneCard(
            color: const Color(0xFFF0F4FF),
            border: const Color(0xFFDBEAFE),
          ),
          child: const Column(
            children: [
              Text(
                '身份认证',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cloneInk,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '只有完成身份认证的用户，才能使用声音克隆服务。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 20 / 13,
                  color: cloneSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final text in const [
          '完成身份认证后，进入声音克隆并生成你的声音。',
          '未经授权，AI 不应使用你的声音进行通话。',
          '后续通话完善声音需单独开启授权。',
        ])
          Text(
            text,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: const TextStyle(
              fontSize: 13,
              height: 23 / 13,
              letterSpacing: .5,
              color: cloneSecondary,
            ),
          ),
        const SizedBox(height: 20),
        CloneCheckRow(
          key: const Key('clone-consent'),
          checked: state.agreed,
          onChanged: state.busy ? null : onAgree,
          label: '我确认由本人申请使用本人声音，并同意进行身份认证',
        ),
        if (state.error.isNotEmpty) ...[
          const SizedBox(height: 20),
          _EnrollmentError(message: state.error),
        ],
        const SizedBox(height: 20),
        ClonePrimaryAction(
          label: state.busy ? '正在进入认证…' : '开始认证',
          onPressed: state.agreed && !state.busy ? onNext : null,
        ),
      ],
    ),
  );
}

class CloneIdentityStep extends StatefulWidget {
  const CloneIdentityStep({
    super.key,
    required this.busy,
    required this.onSubmit,
    this.preview = false,
    this.verifiedName = '',
    this.prefilledName = '',
    this.verifiedIdCardMasked = '',
    this.onNumberEdit,
    this.error = '',
    this.maskIdentity = false,
  });
  final bool busy, preview, maskIdentity;
  final String verifiedName, prefilledName, error, verifiedIdCardMasked;
  final VoidCallback? onNumberEdit;
  final void Function(String, String) onSubmit;
  @override
  State<CloneIdentityStep> createState() => _CloneIdentityStepState();
}

class _CloneIdentityStepState extends State<CloneIdentityStep> {
  final _name = TextEditingController(), _number = TextEditingController();
  final _maskedName = TextEditingController(),
      _maskedNumber = TextEditingController();
  final _nameFocus = FocusNode(), _numberFocus = FocusNode();
  bool _nameMasked = false, _numberMasked = false;
  void _editName() {
    if (!_nameFocus.hasFocus ||
        !_nameMasked ||
        widget.verifiedName.isNotEmpty) {
      return;
    }
    setState(() {
      _name.clear();
      _nameMasked = false;
    });
  }

  void _editNumber() {
    if (!_numberFocus.hasFocus) return;
    if (_numberMasked) {
      setState(() {
        _number.clear();
        _numberMasked = false;
      });
    }
    widget.onNumberEdit?.call();
  }

  void _maskName() {
    final name = _name.text.trim();
    _nameMasked = true;
    _maskedName.text = name.isEmpty
        ? ''
        : name.length == 1
        ? '*'
        : name[0] + '*' * (name.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _name.text = widget.verifiedName.isNotEmpty
        ? widget.verifiedName
        : widget.prefilledName;
    if (widget.verifiedName.isNotEmpty || widget.maskIdentity) _maskName();
    _nameFocus.addListener(_editName);
    _numberFocus.addListener(_editNumber);
  }

  @override
  void didUpdateWidget(covariant CloneIdentityStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verifiedName.isNotEmpty &&
        widget.verifiedName.isEmpty &&
        widget.prefilledName.isEmpty) {
      _name.clear();
      _number.clear();
      _maskedName.clear();
      _maskedNumber.clear();
      _nameMasked = _numberMasked = false;
      _nameFocus.unfocus();
      _numberFocus.unfocus();
    }
    if (widget.verifiedName != oldWidget.verifiedName &&
        widget.verifiedName.isNotEmpty) {
      _name.text = widget.verifiedName;
      _maskName();
    }
    if (widget.maskIdentity && !oldWidget.maskIdentity) {
      _nameFocus.unfocus();
      _numberFocus.unfocus();
      _nameMasked = _numberMasked = true;
      final name = _name.text.trim();
      _maskedName.text = name.isEmpty
          ? ''
          : name.length == 1
          ? '*'
          : name[0] + '*' * (name.length - 1);
      final number = _number.text.trim();
      _maskedNumber.text = number.length <= 7
          ? '*' * number.length
          : number.substring(0, 3) +
                '*' * (number.length - 7) +
                number.substring(number.length - 4);
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _numberFocus.dispose();
    _maskedName.dispose();
    _maskedNumber.dispose();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.preview
            ? '仅填写合成数据，不要输入真实身份信息'
            : widget.verifiedName.isNotEmpty
            ? '认证姓名已锁定，请重新输入本人身份证号继续认证'
            : '请填写本人真实姓名和身份证号',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: cloneTextSpacing(context, 12),
          height: 17 / 12,
          color: Color(0xFFB0B4C3),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: cloneCard(),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '姓名',
                style: TextStyle(fontSize: 13, color: Color(0xFF8B8FA3)),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: '姓名',
              child: TextField(
                controller: _nameMasked ? _maskedName : _name,
                focusNode: _nameFocus,
                onTap: _editName,
                enabled: !widget.busy && widget.verifiedName.isEmpty,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                textInputAction: TextInputAction.next,
                decoration: _identityDecoration('请输入姓名'),
                autofillHints: const [],
              ),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '身份证号',
                style: TextStyle(fontSize: 13, color: Color(0xFF8B8FA3)),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.verifiedName.isNotEmpty &&
                widget.verifiedIdCardMasked.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '已认证身份证：${widget.verifiedIdCardMasked}',
                  key: const Key('clone-verified-id-card'),
                  style: const TextStyle(fontSize: 13, color: cloneSecondary),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Semantics(
              label: '身份证号',
              child: TextField(
                controller: _numberMasked ? _maskedNumber : _number,
                focusNode: _numberFocus,
                onTap: _editNumber,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                enabled: !widget.busy,
                maxLength: 18,
                inputFormatters: [
                  TextInputFormatter.withFunction(_formatIdentityInput),
                ],
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.visiblePassword,
                decoration: _identityDecoration('请输入18位大陆身份证号'),
                autofillHints: const [],
              ),
            ),
          ],
        ),
      ),
      if (widget.preview)
        TextButton(
          onPressed: widget.busy
              ? null
              : () {
                  _name.text = '演练用户';
                  _number.text = '000000200001010005';
                },
          child: const Text('填入合成测试数据'),
        ),
      if (widget.error.isNotEmpty) ...[
        const SizedBox(height: 16),
        _EnrollmentError(message: widget.error),
      ],
      const SizedBox(height: 16),
      Text(
        '提交后将进入阿里云人脸与跟读认证。同一次跟读会同时用于声音克隆，不会再次要求录音。',
        style: TextStyle(
          fontSize: 13,
          height: 21 / 13,
          letterSpacing: cloneTextSpacing(context, 13),
          color: Color(0xFF6B7280),
        ),
      ),
      const SizedBox(height: 16),
      ClonePrimaryAction(
        onPressed: widget.busy
            ? null
            : () => widget.onSubmit(_name.text, _number.text),
        label: widget.busy ? '正在准备认证…' : '开始人脸跟读认证',
      ),
      if (widget.busy) ...[
        const SizedBox(height: 12),
        const Text(
          '阿里云人脸认证组件加载中。首次加载认证资源可能需要十几秒，请保持网络畅通并耐心等待。',
          style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280)),
        ),
      ],
    ],
  );
}

TextEditingValue _formatIdentityInput(
  TextEditingValue previous,
  TextEditingValue value,
) {
  final number = normalizeCloneIdentityInput(value.text, previous.text);
  if (number == previous.text) return previous;
  final leading = value.text.length - value.text.trimLeft().length;
  int offset(int position) =>
      (position - leading).clamp(0, number.length).toInt();
  return value.copyWith(
    text: number,
    selection: value.selection.copyWith(
      baseOffset: offset(value.selection.baseOffset),
      extentOffset: offset(value.selection.extentOffset),
    ),
    composing: TextRange.empty,
  );
}

InputDecoration _identityDecoration(String hint) => InputDecoration(
  hintText: hint,
  counterText: '',
  filled: true,
  fillColor: const Color(0xFFF8FAFC),
  hintStyle: const TextStyle(fontSize: 17, color: Color(0xFFB0B4C3)),
  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B8FA3)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFF0A84FF)),
  ),
);

class _EnrollmentError extends StatelessWidget {
  const _EnrollmentError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Text(
    message,
    key: const ValueKey('clone-flow-error'),
    style: const TextStyle(
      fontSize: 13,
      height: 18 / 13,
      color: Color(0xFFE14D46),
    ),
  );
}
