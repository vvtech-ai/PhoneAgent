import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/design/shell_tokens.dart';
import '../../domain/home_config.dart';

/// Native hero flow with intrinsic height for keyboard and large text layouts.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.slogan,
    required this.modelName,
    required this.onModels,
    this.modelMultiplier,
    this.onWelfare,
    super.key,
  });
  final HomeSlogan slogan;
  final String modelName;
  final VoidCallback onModels;
  final VoidCallback? onWelfare;
  final double? modelMultiplier;
  bool get _showMultiplier =>
      modelMultiplier != null &&
      modelMultiplier!.isFinite &&
      modelMultiplier! > 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
    child: Column(
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xF0FFFFFF), Color(0xF0F1F5FC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: const Color(0xEBFFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A007AFF),
                blurRadius: 36,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Image.asset('assets/images/shell/home_voice_orb.png'),
        ),
        const SizedBox(height: 18),
        Text(
          slogan.title,
          style: ShellTokens.title.copyWith(
            color: const Color(0xFF121826),
            height: 31 / 28,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 292),
          child: Text(
            slogan.subtitle,
            style: ShellTokens.subtitle.copyWith(fontSize: 14, height: 22 / 14),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FilledButton(
                key: const ValueKey('homeVoiceModelChip'),
                onPressed: onModels,
                style: FilledButton.styleFrom(
                  backgroundColor: ShellTokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size(156, 32),
                  shape: const StadiumBorder(),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '通话模型：$modelName',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_showMultiplier) ...[
                      const SizedBox(width: 5),
                      Text(
                        '×${modelMultiplier!.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xC7FFFFFF),
                        ),
                      ),
                    ],
                    const SizedBox(width: 5),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ),
            if (onWelfare != null) ...[
              const SizedBox(width: 6),
              SizedBox.square(
                dimension: 36,
                child: IconButton(
                  key: const Key('home-welfare'),
                  tooltip: '福利',
                  onPressed: onWelfare,
                  padding: const EdgeInsets.all(7),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF4F5F7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: SvgPicture.asset(
                    'assets/images/shell/home_welfare_gift.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
