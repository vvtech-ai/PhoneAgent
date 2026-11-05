import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_directory_providers.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../../dialer/domain/dial_country.dart';
import '../../../dialer/presentation/pages/dial_country_page.dart';
import '../../../dialer/presentation/widgets/dial_location_host.dart';

/// Refreshes published countries without delaying entry or discarding old rows.
Future<String?> pushTranslationCountry(
  BuildContext context, {
  required String selected,
  required bool preview,
  required List<DialCountry> countries,
}) {
  final container = ProviderScope.containerOf(context);
  if (!preview && !container.read(translationDirectoryProvider).isLoading) {
    container.invalidate(translationDirectoryProvider);
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (pageContext) => RouteProviderScope(
        container: container,
        child: _TranslationCountryPage(
          selected: selected,
          preview: preview,
          countries: countries,
        ),
      ),
    ),
  );
}

class _TranslationCountryPage extends ConsumerStatefulWidget {
  const _TranslationCountryPage({
    required this.selected,
    required this.preview,
    required this.countries,
  });
  final String selected;
  final bool preview;
  final List<DialCountry> countries;

  @override
  ConsumerState<_TranslationCountryPage> createState() =>
      _TranslationCountryPageState();
}

class _TranslationCountryPageState
    extends ConsumerState<_TranslationCountryPage> {
  late List<DialCountry> _countries = widget.countries;

  @override
  Widget build(BuildContext context) {
    if (!widget.preview) {
      final options = ref.watch(translationDirectoryProvider);
      if (!options.isLoading && !options.hasError && options.hasValue) {
        _countries = [
          for (final item in options.requireValue.countries)
            DialCountry(
              item.iso,
              item.name,
              item.dialCode,
              dialCountry(item.iso)?.pinyin ?? item.iso,
              dialCountry(item.iso)?.initials ?? item.iso,
            ),
        ];
      }
    }
    return DialCountryPage(
      // The shared page builds its alphabetical index at initialization.
      key: ValueKey(_countries.map((country) => country.iso).join(',')),
      selected: widget.selected,
      countries: _countries,
      location: widget.preview
          ? null
          : DialLocationHost(
              onSelected: (iso) {
                if (context.mounted &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  Navigator.pop(context, iso);
                }
              },
            ),
    );
  }
}
