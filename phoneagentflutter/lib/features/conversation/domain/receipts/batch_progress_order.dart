/// Orders physical facts per route and attempt; business terminal wins.
class BatchProgressOrder {
  final _versions = <String, int>{};
  final _attempts = <int, (String, int)>{};
  final _finished = <int, String>{};
  void clear() {
    _versions.clear();
    _attempts.clear();
    _finished.clear();
  }

  bool accept(int index, Map<String, Object?> data) {
    final attempt = data['callAttemptId']?.toString().trim() ?? '';
    if (attempt.isEmpty) return true;
    final version = int.tryParse('${data['phaseVersion']}') ?? 0;
    final number = int.tryParse('${data['attemptNumber']}') ?? 0;
    final current = _attempts[index];
    if (current != null &&
        current.$1 != attempt &&
        (number <= 0 || number <= current.$2)) {
      return false;
    }
    final key = '$index:$attempt';
    if (version == 0 &&
        (_versions[key] ?? 0) > 0 &&
        data['evidenceLevel'] == 'ADMISSION') {
      return false;
    }
    if (version > 0 && version < (_versions[key] ?? 0)) return false;
    final phase = data['phase']?.toString().trim() ?? '';
    final status = (data['status'] ?? data['batchStatus'])
        ?.toString()
        .toUpperCase();
    final terminal =
        (phase.isEmpty &&
            const {
              'SUCCESS',
              'FAILED',
              'UNCLEAR',
              'USER_CANCELLED',
            }.contains(status)) ||
        phase == 'FAILED';
    if (_finished[index] == attempt && !terminal) return false;
    if (current != null && current.$1 != attempt) _finished.remove(index);
    _attempts[index] = (attempt, number > 0 ? number : current?.$2 ?? 0);
    if (version > 0) _versions[key] = version;
    if (terminal) _finished[index] = attempt;
    return true;
  }

  bool finished(int index, String attempt) =>
      attempt.isNotEmpty && _finished[index] == attempt;

  static String status(Map<String, Object?> data) {
    final phase = data['phase']?.toString().trim().toUpperCase() ?? '';
    if (const {
      'CALLING',
      'RINGING',
      'CONNECTED',
      'ENDING',
      'CANCELLING',
      'STOP_ACCEPTED',
      'PRIMARY_CLOSED_FORK_OBSERVING',
      'PHYSICAL_CLOSED',
      'RESULT_PENDING',
      'FAILED',
    }.contains(phase)) {
      return phase;
    }
    return (data['status'] ?? data['batchStatus'])?.toString() ?? '';
  }
}
