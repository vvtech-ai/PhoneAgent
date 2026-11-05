import 'package:flutter/material.dart';
import 'invite_reward_artwork.dart';

/// v67 InviteRewardCard uses the 544×518 original illustration proportions.
class InviteRewardCard extends StatelessWidget {
  const InviteRewardCard({
    super.key,
    required this.amount,
    required this.error,
    required this.onConfirm,
  });
  final int amount;
  final String error;
  final VoidCallback? onConfirm;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final unit = constraints.maxWidth / 544;
              if (MediaQuery.textScalerOf(context).scale(24) > 24) {
                return _largeTextCard(unit);
              }
              Widget label(
                String text,
                double top,
                double font,
                Color color,
                FontWeight weight,
              ) => Positioned(
                top: top * unit,
                left: 12 * unit,
                right: 12 * unit,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: font * unit,
                      color: color,
                      fontWeight: weight,
                    ),
                  ),
                ),
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(50 * unit),
                child: ColoredBox(
                  color: const Color(0xFFFAFDFF),
                  child: AspectRatio(
                    aspectRatio: 544 / 518,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: InviteRewardArtwork()),
                        ),
                        label(
                          '好友邀请奖励已到账',
                          198,
                          24,
                          const Color(0xFF5C7089),
                          FontWeight.w800,
                        ),
                        Positioned(
                          top: 241 * unit,
                          left: 24 * unit,
                          right: 24 * unit,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '+$amount',
                                  style: TextStyle(
                                    fontSize: 72 * unit,
                                    height: 86 / 72,
                                    color: const Color(0xFF197CF4),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 12 * unit,
                                    bottom: 9 * unit,
                                  ),
                                  child: Text(
                                    '积分',
                                    style: TextStyle(
                                      fontSize: 32 * unit,
                                      color: const Color(0xFF263B58),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        label(
                          '已存入你的积分账户',
                          329,
                          20,
                          const Color(0xFF94A2B6),
                          FontWeight.w400,
                        ),
                        Positioned(
                          bottom: 43 * unit,
                          left: 47 * unit,
                          right: 47 * unit,
                          height: 85 * unit,
                          child: FilledButton(
                            onPressed: onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1683F8),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26 * unit),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '确定',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontSize: 28 * unit,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
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
            },
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error,
                style: const TextStyle(color: Color(0xFFE34242)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _largeTextCard(double unit) => ClipRRect(
    borderRadius: BorderRadius.circular(50 * unit),
    child: ColoredBox(
      color: const Color(0xFFFAFDFF),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: InviteRewardArtwork()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24 * unit,
              198 * unit,
              24 * unit,
              43 * unit,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '好友邀请奖励已到账',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24 * unit,
                    height: 34 / 24,
                    color: const Color(0xFF5C7089),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 9 * unit),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12 * unit,
                  runSpacing: 6 * unit,
                  children: [
                    Text(
                      '+$amount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 72 * unit,
                        height: 86 / 72,
                        color: const Color(0xFF197CF4),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '积分',
                      style: TextStyle(
                        fontSize: 32 * unit,
                        color: const Color(0xFF263B58),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8 * unit),
                Text(
                  '已存入你的积分账户',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20 * unit,
                    height: 28 / 20,
                    color: const Color(0xFF94A2B6),
                  ),
                ),
                SizedBox(height: 28 * unit),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 23 * unit),
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1683F8),
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, 85 * unit),
                      padding: EdgeInsets.symmetric(vertical: 16 * unit),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26 * unit),
                      ),
                    ),
                    child: Text(
                      '确定',
                      style: TextStyle(
                        fontSize: 28 * unit,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
