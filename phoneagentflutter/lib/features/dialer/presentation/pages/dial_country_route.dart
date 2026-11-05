import '../../domain/dial_country.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../widgets/dial_location_host.dart';
import 'dial_country_page.dart';

/// Selection owns its route; a late location result cannot pop another page.
Future<String?> pushDialCountry(
  BuildContext context, {
  required String selected,
  required bool preview,
  List<DialCountry> countries = dialCountries,
}) {
  final container = ProviderScope.containerOf(context);
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (pageContext) => RouteProviderScope(
        container: container,
        child: DialCountryPage(
          selected: selected,
          countries: countries,
          location: preview
              ? null
              : DialLocationHost(
                  onSelected: (iso) {
                    if (pageContext.mounted &&
                        ModalRoute.of(pageContext)?.isCurrent == true) {
                      Navigator.pop(pageContext, iso);
                    }
                  },
                ),
        ),
      ),
    ),
  );
}
