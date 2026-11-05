import 'package:flutter/material.dart';
import '../../domain/dial_country.dart';

String dialCountryFlagEmoji(String iso) {
  final normalized = iso.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '🌐';
  return String.fromCharCodes(
    normalized.codeUnits.map((code) => 0x1F1E6 + code - 0x41),
  );
}

class DialCountryFlag extends StatelessWidget {
  const DialCountryFlag({super.key, required this.country});
  final DialCountry country;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.asset(
        country.flagAsset,
        width: 26,
        height: 18,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => SizedBox(
          width: 26,
          height: 18,
          child: Center(
            child: Text(
              dialCountryFlagEmoji(country.iso),
              textScaler: const TextScaler.linear(.78),
              style: const TextStyle(fontSize: 22, height: 1),
            ),
          ),
        ),
      ),
    ),
  );
}

class DialCountryRow extends StatelessWidget {
  const DialCountryRow({
    super.key,
    required this.country,
    required this.selected,
    required this.onTap,
  });
  final DialCountry country;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: true,
    label: '${country.name}，${country.code}',
    selected: selected,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              DialCountryFlag(country: country),
              const SizedBox(width: 11),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        country.name,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF202228),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      country.code,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: Color(0xFF1687F8),
                        semanticLabel: '已选择',
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DialCountrySectionHeader extends StatelessWidget {
  const DialCountrySectionHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFF1F3F7),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF667085),
      ),
    ),
  );
}
