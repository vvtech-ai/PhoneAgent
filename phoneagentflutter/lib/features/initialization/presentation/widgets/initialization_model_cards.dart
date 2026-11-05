import 'package:flutter/material.dart';
import '../../domain/initialization_gateway.dart';

/// Shared native 16/15 padding and a visual radio; the entire card owns input.
class InitializationModelCards extends StatelessWidget {
  const InitializationModelCards({
    super.key,
    required this.catalog,
    required this.selected,
    required this.busy,
    required this.onSelect,
  });
  final InitializationCatalog catalog;
  final String selected;
  final bool busy;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) =>
      Column(children: [for (final model in catalog.models) _card(model)]);

  Widget _card(InitializationModel model) {
    final capability = model.capability == model.description.trim()
        ? ''
        : model.capability;
    final chosen = selected == model.id && model.enabled;
    final enabled = model.enabled && !busy;
    final activate = enabled ? () => onSelect(model.id) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        button: true,
        label: [
          model.name,
          model.description,
          capability,
          if (model.recommended) '推荐',
        ].where((value) => value.isNotEmpty).join('，'),
        selected: chosen,
        enabled: enabled,
        onTap: activate,
        excludeSemantics: true,
        child: Material(
          key: ValueKey('init-model-${model.id}'),
          color: !model.enabled
              ? const Color(0xFFF7F7F8)
              : chosen
              ? const Color(0x0F2196F3)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: chosen
                  ? const Color(0xFF2196F3)
                  : model.enabled
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: activate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            model.name,
                            style: TextStyle(
                              fontSize: 16,
                              height: 19 / 16,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w700,
                              color: model.enabled
                                  ? const Color(0xFF111111)
                                  : const Color(0xFF9B9BA1),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            model.description,
                            style: TextStyle(
                              fontSize: 12,
                              height: 14 / 12,
                              letterSpacing: 0,
                              color: model.enabled
                                  ? const Color(0xFF667085)
                                  : const Color(0xFFAEAEB2),
                            ),
                          ),
                          if (capability.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              capability,
                              style: TextStyle(
                                fontSize: 12,
                                height: 14 / 12,
                                letterSpacing: 0,
                                color: model.enabled
                                    ? const Color(0xFF667085)
                                    : const Color(0xFFAEAEB2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (model.recommended) ...[
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF5FF),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            '推荐',
                            style: TextStyle(
                              fontSize: 11,
                              height: 13 / 11,
                              letterSpacing: 0,
                              color: Color(0xFF0A84FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    SizedBox.square(
                      key: ValueKey('init-model-radio-${model.id}'),
                      dimension: 20,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 1.5,
                            color: chosen
                                ? const Color(0xFF2196F3)
                                : model.enabled
                                ? const Color(0xFF98A2B3)
                                : const Color(0xFFCCD3DE),
                          ),
                        ),
                        child: chosen
                            ? const Center(
                                child: SizedBox.square(
                                  dimension: 10,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
