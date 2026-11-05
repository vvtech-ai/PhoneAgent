class AgentClockSnapshot {
  AgentClockSnapshot({
    required this.epochMillis,
    required this.offsetSeconds,
    required this.timezone,
  }) {
    if (offsetSeconds.abs() > 18 * 3600 ||
        !RegExp(r'^[A-Za-z0-9_./:+-]{1,100}$').hasMatch(timezone)) {
      throw const FormatException('Invalid clock snapshot');
    }
    final year = DateTime.fromMillisecondsSinceEpoch(
      epochMillis,
      isUtc: true,
    ).year;
    if (year < 1 || year > 9999) {
      throw const FormatException('Invalid clock year');
    }
  }
  final int epochMillis, offsetSeconds;
  final String timezone;

  static String offsetText(int seconds) {
    final absolute = seconds.abs();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${seconds < 0 ? '-' : '+'}${two(absolute ~/ 3600)}:${two(absolute ~/ 60 % 60)}'
        '${absolute % 60 == 0 ? '' : ':${two(absolute % 60)}'}';
  }

  /// Fallback states the known numeric offset, not a guessed regional zone.
  factory AgentClockSnapshot.localNow() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset.inSeconds;
    return AgentClockSnapshot(
      epochMillis: now.millisecondsSinceEpoch,
      offsetSeconds: offset,
      timezone: offsetText(offset),
    );
  }

  Map<String, Object?> toContext() {
    final wall = DateTime.fromMillisecondsSinceEpoch(
      epochMillis,
      isUtc: true,
    ).add(Duration(seconds: offsetSeconds)).toIso8601String();
    return {
      'isoDateTime':
          '${wall.substring(0, wall.length - 1)}${offsetText(offsetSeconds)}',
      'timezone': timezone,
    };
  }
}

abstract interface class AgentClockSource {
  Future<AgentClockSnapshot> read();
}
