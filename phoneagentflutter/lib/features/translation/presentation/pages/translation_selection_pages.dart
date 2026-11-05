import 'package:flutter/material.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_detail_header.dart';
import '../../../../core/design/native_setting_controls.dart';
import '../../domain/translation_preferences.dart';
import '../controller/translation_setup_controller.dart';
import '../widgets/translation_storage_status.dart';

class TranslationLanguagePage extends StatelessWidget {
  const TranslationLanguagePage({
    super.key,
    required this.caller,
    required this.selected,
    this.supportedLanguageCodes,
    this.languages = translationLanguages,
  });
  final List<TranslationLanguage> languages;
  final bool caller;
  final String selected;
  final Set<String>? supportedLanguageCodes;

  bool _isSupported(String code) =>
      supportedLanguageCodes == null || supportedLanguageCodes!.contains(code);

  void _finish(BuildContext context, [String? code]) {
    if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) => NativePageBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 18, 20, 10),
              child: Row(
                children: [
                  Semantics(
                    container: true,
                    button: true,
                    enabled: true,
                    label: '返回',
                    onTap: () => _finish(context),
                    child: ExcludeSemantics(
                      child: IconButton(
                        tooltip: '返回',
                        onPressed: () => _finish(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      caller ? '我的语言' : '对方语言',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111318),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final language in languages)
                    Semantics(
                      container: true,
                      button: true,
                      enabled: _isSupported(language.code),
                      label: '${language.label}，${language.nativeLabel}',
                      onTap: _isSupported(language.code)
                          ? () => _finish(context, language.code)
                          : null,
                      selected:
                          _isSupported(language.code) &&
                          language.code == selected,
                      child: ExcludeSemantics(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('language-${language.code}'),
                            onTap: _isSupported(language.code)
                                ? () => _finish(context, language.code)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final supported = _isSupported(
                                          language.code,
                                        );
                                        final name = Text(
                                          language.label,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: supported
                                                ? const Color(0xFF202228)
                                                : const Color(0xFFB4BAC5),
                                          ),
                                        );
                                        final native = Text(
                                          supported
                                              ? language.nativeLabel
                                              : '当前模型不支持',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: supported
                                                ? const Color(0xFF8A8F9D)
                                                : const Color(0xFFB4BAC5),
                                          ),
                                        );
                                        double width(Text text) {
                                          final painter = TextPainter(
                                            text: TextSpan(
                                              text: text.data,
                                              style: text.style,
                                            ),
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                            textScaler: MediaQuery.textScalerOf(
                                              context,
                                            ),
                                          )..layout();
                                          final measured = painter.width;
                                          painter.dispose();
                                          return measured;
                                        }

                                        final compact =
                                            width(name) + width(native) + 12 >
                                            constraints.maxWidth;
                                        return compact
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  name,
                                                  const SizedBox(height: 4),
                                                  native,
                                                ],
                                              )
                                            : Row(
                                                children: [
                                                  Expanded(child: name),
                                                  native,
                                                ],
                                              );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child:
                                        _isSupported(language.code) &&
                                            language.code == selected
                                        ? const Icon(
                                            Icons.check,
                                            size: 20,
                                            color: Color(0xFF1687F8),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TranslationSettingsPage extends StatefulWidget {
  const TranslationSettingsPage({
    super.key,
    required this.controller,
    this.serviceStatusBuilder,
    this.canEdit,
  });
  final TranslationSetupController controller;
  final Widget Function(String region)? serviceStatusBuilder;
  final bool Function()? canEdit;
  @override
  State<TranslationSettingsPage> createState() =>
      _TranslationSettingsPageState();
}

class _TranslationSettingsPageState extends State<TranslationSettingsPage> {
  bool get _current => mounted && ModalRoute.of(context)?.isCurrent == true;
  bool get _editable =>
      _current &&
      widget.controller.mounted &&
      widget.controller.status.ready &&
      (widget.canEdit?.call() ?? true);
  late final void Function() _unsubscribe;
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
    return NativePageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              NativeDetailHeader(
                title: '海外实时翻译',
                onBack: () {
                  if (_current) Navigator.pop(context);
                },
              ),
              TranslationStorageStatus(controller: widget.controller),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    const Text(
                      '实时翻译模型',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '只影响之后新发起的海外实时翻译通话',
                      style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final entry in const {
                          'OPENAI': 'GPT Live Translate',
                          'GEMINI': 'Gemini Live',
                        }.entries)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: entry.key == 'OPENAI' ? 10 : 0,
                              ),
                              child: NativeSettingChoice(
                                key: ValueKey(
                                  'translation-setting-model-${entry.key}',
                                ),
                                label: entry.value,
                                selected: state.provider == entry.key,
                                onTap: () {
                                  if (_editable) {
                                    widget.controller.provider(entry.key);
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '服务部署区域',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '通话节点按主叫所在国家匹配，可在下方检查各区域支持的语言',
                      style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                    ),
                    const SizedBox(height: 8),
                    if (widget.serviceStatusBuilder != null)
                      widget.serviceStatusBuilder!(state.region),
                    for (final entry in const {
                      'DEFAULT': 'Default · 默认服务部署',
                      'US': 'US · 美国服务部署',
                      'JP': 'JP · 日本服务部署',
                    }.entries)
                      NativeSettingCard(
                        key: ValueKey(
                          'translation-setting-region-${entry.key}',
                        ),
                        title: entry.key == 'DEFAULT' ? 'Default' : entry.key,
                        subtitle: entry.value.split(' · ').last,
                        value: state.region == entry.key ? '已选择' : '›',
                        onTap: () {
                          if (_editable) widget.controller.region(entry.key);
                        },
                      ),
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
