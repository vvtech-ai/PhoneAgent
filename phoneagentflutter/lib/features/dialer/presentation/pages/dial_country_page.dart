import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/dial_country_rows.dart';
import '../widgets/dial_country_index.dart';
import '../../domain/dial_country.dart';

class DialCountryPage extends StatefulWidget {
  const DialCountryPage({
    super.key,
    required this.selected,
    this.location,
    this.countries = dialCountries,
  });
  final List<DialCountry> countries;
  final String selected;
  final Widget? location;
  @override
  State<DialCountryPage> createState() => _DialCountryPageState();
}

class _DialCountryPageState extends State<DialCountryPage> {
  bool _finished = false;
  void _finish([String? iso]) {
    if (_finished || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _finished = true;
    Navigator.pop(context, iso);
  }

  String _query = '';
  String? _feedback;
  Timer? _feedbackTimer;
  late final _sections = {
    for (final title in [
      'G20',
      ...widget.countries.map((c) => c.section).toSet().toList()..sort(),
    ])
      title: GlobalKey(),
  };
  void _jump(String title) {
    final target = _sections[title]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target);
    setState(() => _feedback = title);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.countries
        .where((country) => country.matches(_query))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
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
                    onTap: _finish,
                    excludeSemantics: true,
                    child: IconButton(
                      tooltip: '返回',
                      onPressed: _finish,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '选择国家或地区',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111318),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                key: const Key('dial-country-search'),
                style: const TextStyle(fontSize: 15, color: Color(0xFF202228)),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: '搜索国家、地区或区号',
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF98A2B3),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Color(0xFF98A2B3),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFEFF1F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    key: const Key('dial-country-list'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.location != null) widget.location!,
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Text(
                              '暂无匹配的国家或地区',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ),
                        if (_query.isEmpty) ...[
                          DialCountrySectionHeader(
                            key: _sections['G20'],
                            title: 'G20',
                          ),
                          for (final country in rows.where(
                            (country) => country.inG20,
                          ))
                            _row(country, g20: true),
                          for (final title in _sections.keys.where(
                            (title) => title != 'G20',
                          )) ...[
                            DialCountrySectionHeader(
                              key: _sections[title],
                              title: title,
                            ),
                            for (final country in rows.where(
                              (country) => country.section == title,
                            ))
                              _row(country),
                          ],
                        ] else
                          for (final country in rows) _row(country),
                      ],
                    ),
                  ),
                  if (_query.isEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: DialCountryIndex(
                        sections: _sections.keys.toList(),
                        onSection: _jump,
                      ),
                    ),
                  if (_feedback != null && _query.isEmpty)
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xCC344054),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _feedback!,
                            key: const Key('dial-index-feedback'),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: _feedback == 'G20' ? 22 : 32,
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
    );
  }

  Widget _row(DialCountry country, {bool g20 = false}) => DialCountryRow(
    key: Key(
      g20 ? 'dial-country-g20-${country.iso}' : 'dial-country-${country.iso}',
    ),
    country: country,
    selected: country.iso == widget.selected,
    onTap: () => _finish(country.iso),
  );
}
