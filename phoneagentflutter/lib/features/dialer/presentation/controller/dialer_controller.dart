import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/dial_country.dart';
import '../../domain/contact_dial_input.dart';
import '../../domain/dial_phone_policy.dart';
import '../../domain/system_dialer.dart';
import '../../domain/dial_recent_call.dart';
import '../../../translation/domain/translation_directory.dart';

class DialerState {
  const DialerState({
    this.input = '',
    this.countryIso = 'CN',
    this.name = '',
    this.busy = false,
    this.message = '',
    this.preview = false,
    this.configuredCountry,
  });
  final String input, countryIso, name, message;
  final bool busy, preview;
  final DialCountry? configuredCountry;
  DialCountry get country => configuredCountry?.iso == countryIso
      ? configuredCountry!
      : dialCountry(countryIso)!;
  DialerState copy({
    String? input,
    String? countryIso,
    DialCountry? configuredCountry,
    String? name,
    bool? busy,
    String? message,
  }) => DialerState(
    input: input ?? this.input,
    countryIso: countryIso ?? this.countryIso,
    configuredCountry: configuredCountry ?? this.configuredCountry,
    name: name ?? this.name,
    busy: busy ?? this.busy,
    message: message ?? this.message,
    preview: preview,
  );
}

class DialerController extends StateNotifier<DialerState> {
  DialerController(
    this._dialer, {
    bool preview = false,
    this.onUnlockDeveloper,
    this.onOpened,
  }) : super(DialerState(preview: preview));
  final SystemDialer _dialer;
  final void Function()? onUnlockDeveloper;
  final Future<void> Function(String phone, String name, String countryIso)?
  onOpened;
  void digit(String digit) {
    if (state.busy || !RegExp(r'^[0-9*#]$').hasMatch(digit)) return;
    if (RegExp(r'[0-9]').hasMatch(digit) &&
        DialPhonePolicy.digits(state.input).length >= 14) {
      state = state.copy(message: '号码最多输入14位');
      return;
    }
    state = state.copy(input: '${state.input}$digit', name: '', message: '');
  }

  void delete() {
    if (!state.busy && state.input.isNotEmpty) {
      state = state.copy(
        input: state.input.substring(0, state.input.length - 1),
        name: '',
        message: '',
      );
    }
  }

  void clear() {
    if (!state.busy) state = state.copy(input: '', name: '', message: '');
  }

  void country(String iso, {DialCountry? configuredCountry}) {
    if (!state.busy &&
        (configuredCountry?.iso == iso || dialCountry(iso) != null)) {
      state = state.copy(
        countryIso: iso,
        configuredCountry: configuredCountry,
        message: '',
      );
    }
  }

  void consumeMessage(String expected) {
    if (mounted && state.message == expected && expected.isNotEmpty) {
      state = state.copy(message: '');
    }
  }

  void prepare(
    String raw, {
    String name = '',
    TranslationDirectory? directory,
    String? defaultIso,
  }) {
    if (state.busy) return;
    final value = contactDialInput(
      raw,
      defaultIso: defaultIso ?? state.countryIso,
      directory: directory,
    );
    final configured = directory?.country(value.iso);
    state = value.error.isEmpty
        ? state.copy(
            input: value.number,
            countryIso: value.iso,
            configuredCountry: configured == null
                ? null
                : DialCountry(
                    configured.iso,
                    configured.name,
                    configured.dialCode,
                    dialCountry(configured.iso)?.pinyin ?? configured.iso,
                    dialCountry(configured.iso)?.initials ?? configured.iso,
                  ),
            name: name,
            message: '',
          )
        : state.copy(input: '', name: '', message: value.error);
  }

  Future<void> dial({bool allowUnverifiedNumber = false}) async {
    if (!mounted || state.busy) return;
    // Never accidentally pass the developer unlock sequence to the phone app.
    if (state.input == '20142014*#') {
      if (!state.preview) onUnlockDeveloper?.call();
      state = state.copy(
        input: '',
        name: '',
        message: state.preview
            ? 'MOCK · 已识别开发者拨号串，未改变正式设置'
            : onUnlockDeveloper == null
            ? '开发者功能暂不可用'
            : '已进入开发者模式',
      );
      return;
    }
    final target = DialPhonePolicy.resolveForCall(
      state.input,
      state.countryIso,
      configuredCountry: state.country,
      allowUnverifiedNumber: allowUnverifiedNumber,
    );
    if (target == null) {
      state = state.copy(message: '请输入正确的电话号码');
      return;
    }
    final attempt = state;
    state = state.copy(busy: true, message: '');
    SystemDialResult result;
    try {
      result = await _dialer.open(target.number);
    } catch (_) {
      result = SystemDialResult.failed;
    }
    var recordFailed = false;
    if (result == SystemDialResult.opened && !attempt.preview) {
      try {
        // Record the completed handoff even if its sheet has since closed.
        // The account-bound repository rejects expired login ownership.
        await onOpened?.call(target.number, attempt.name, attempt.countryIso);
      } catch (_) {
        recordFailed = true;
      }
    }
    if (!mounted) return;
    state = state.copy(
      busy: false,
      message: switch (result) {
        SystemDialResult.opened =>
          state.preview
              ? 'MOCK · 已模拟交给系统电话，没有拨出电话'
              : recordFailed
              ? '已交给系统电话，但本机记录保存失败；请勿重复拨号'
              : '已交给系统电话，请在系统界面确认',
        SystemDialResult.unsupported => '当前环境不能打开系统电话，没有发起通话',
        SystemDialResult.invalid => '请输入正确的电话号码',
        SystemDialResult.failed => '无法打开系统拨号盘，请稍后重试',
      },
    );
  }

  bool restoreRecent(DialRecentCall record, {TranslationDirectory? directory}) {
    if (!mounted || state.busy || !record.selectable) return false;
    prepare(
      record.restorablePhone,
      name: record.name,
      directory: directory,
      defaultIso: record.countryIso.isEmpty ? null : record.countryIso,
    );
    if (state.message.isNotEmpty) return false;
    if (record.countryIso.isNotEmpty) country(record.countryIso);
    return true;
  }
}
