enum CallConfirmationIntent { confirm, ambiguous, continueConversation }

enum CallReplyDecision {
  confirm,
  edit,
  cancel,
  newRequest,
  question,
  wait,
  unclear,
}

/// v66 local intent precedence: a conflicting instruction never authorizes dialing.
abstract final class CallConfirmationPolicy {
  static const _confirm = {
    '确认',
    '确认拨打',
    '确定拨打',
    '拨打',
    '打电话',
    '可以拨打',
    '开始拨打',
    '现在拨打',
    '现在打吧',
    '直接拨打',
    '直接打吧',
    '拨打吧',
    '请拨打',
  };
  static const _affirmative = {
    '嗯',
    '嗯嗯',
    '好的',
    '是的',
    '没问题',
    '没错',
    '好',
    '可以',
    '行',
    '同意',
    '对',
    '对啊',
    '对呀',
    '是',
    '打吧',
    '都行',
  };
  static const _suffixes = {
    '确认拨打',
    '确定拨打',
    '可以拨打',
    '开始拨打',
    '现在拨打',
    '现在打吧',
    '直接拨打',
    '直接打吧',
    '直接打',
    '拨打吧',
    '请拨打',
  };
  static const _negative = {
    '不要打',
    '不要拨打',
    '不拨打',
    '不打',
    '别打',
    '别拨打',
    '先不要',
    '不用打',
    '先别打',
    '暂不拨打',
    '取消',
    '不确认',
    '先不打',
    '不打了',
  };
  static const _nonConfirm = {
    '等一下',
    '稍后',
    '晚点',
    '先等',
    '如果',
    '要是',
    '能不能',
    '可不可以',
    '？',
    '?',
    '吗',
    '么',
  };
  static const _noEdit = {'不修改', '不用修改', '无需修改', '不改了', '不用改'};
  static final _noEditPhrase = RegExp(r'(?:没有|没什么|没啥).{0,8}?(?:修改|要改)');

  static bool _hasEdit(String text) {
    var remaining = text.replaceAll(_noEditPhrase, '');
    for (final phrase in _noEdit) {
      remaining = remaining.replaceAll(phrase, '');
    }
    return ['修改', '改成', '换成', '调整'].any(remaining.contains);
  }

  static bool noEditAnswer(String text) =>
      _noEditPhrase.hasMatch(text) && !_hasEdit(text);
  static bool editOrCancel(String text) =>
      _negative.any(text.contains) || _hasEdit(text);
  static bool blocking(String text) =>
      editOrCancel(text) || _nonConfirm.any(text.contains);

  static CallConfirmationIntent classify(String text) {
    final value = text.trim().replaceAll(RegExp(r'[，。！？,.!?；;：:\s]+'), '');
    if (blocking(text)) return CallConfirmationIntent.continueConversation;
    if (_affirmative.contains(value) ||
        _confirm.contains(value) ||
        _suffixes.any(value.endsWith) ||
        _confirm.any(
          (c) =>
              value.startsWith(c) &&
              _affirmative.contains(value.substring(c.length)),
        ) ||
        _affirmative.any(
          (a) =>
              value.startsWith(a) &&
              _confirm.contains(value.substring(a.length)),
        )) {
      return CallConfirmationIntent.confirm;
    }
    return value == '随便'
        ? CallConfirmationIntent.ambiguous
        : CallConfirmationIntent.continueConversation;
  }
}
