import 'package:flutter/material.dart';

class DialCountryIndex extends StatelessWidget {
  const DialCountryIndex({
    super.key,
    required this.sections,
    required this.onSection,
  });
  final List<String> sections;
  final ValueChanged<String> onSection;
  void _select(double y, double height) {
    if (sections.isEmpty || height <= 0) return;
    onSection(
      sections[((y / height) * sections.length).floor().clamp(
        0,
        sections.length - 1,
      )],
    );
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) => _select(
        details.localPosition.dy,
        (context.findRenderObject()! as RenderBox).size.height,
      ),
      onVerticalDragUpdate: (details) => _select(
        details.localPosition.dy,
        (context.findRenderObject()! as RenderBox).size.height,
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final section in sections)
              Semantics(
                button: true,
                label: '跳到$section分组',
                child: GestureDetector(
                  key: Key('dial-index-$section'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSection(section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: .5,
                    ),
                    child: Text(
                      section,
                      style: TextStyle(
                        fontSize: section == 'G20' ? 8 : 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1687F8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
