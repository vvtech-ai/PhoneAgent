/// Transient phone facts. Neither closure observation nor a preview is a receipt.
class CallProgress {
  const CallProgress({
    this.connectedObserved = false,
    this.closureObserved = false,
    this.primaryClosed = false,
    this.preview,
  });
  final bool connectedObserved, closureObserved, primaryClosed;
  final CallOutcomePreview? preview;

  CallProgress observe(
    String status, {
    bool failed = false,
    bool closed = false,
  }) {
    final phase = status.trim().toUpperCase();
    final connected = connectedObserved || phase == 'CONNECTED';
    if (phase == 'CONNECTED' &&
        closureObserved &&
        !primaryClosed &&
        !failed &&
        !closed) {
      return const CallProgress(connectedObserved: true);
    }
    if (!const {'ENDING', 'CANCELLING'}.contains(phase) ||
        !(failed || closed)) {
      if (connected == connectedObserved) return this;
      return CallProgress(
        connectedObserved: connected,
        closureObserved: closureObserved,
        primaryClosed: primaryClosed,
        preview: preview,
      );
    }
    return CallProgress(
      connectedObserved: connected,
      closureObserved: true,
      primaryClosed: primaryClosed || closed,
      preview: preview,
    );
  }

  CallProgress withPreview(Map<String, Object?> data) {
    if (!primaryClosed) return this;
    final next = CallOutcomePreview.parse(data);
    if (next == null || next.sequence <= (preview?.sequence ?? -1)) return this;
    return CallProgress(
      connectedObserved: connectedObserved,
      closureObserved: true,
      primaryClosed: true,
      preview: next,
    );
  }
}

class CallOutcomePreview {
  const CallOutcomePreview(
    this.sequence,
    this.outcome,
    this.headline,
    this.detail,
  );
  final int sequence;
  final String outcome, headline, detail;
  static CallOutcomePreview? parse(Map<String, Object?> data) {
    bool flag(String key) => data[key] == true || data[key] == 'true';
    final sequence = int.tryParse('${data['phoneProgressSeq']}');
    final outcome = '${data['outcome'] ?? ''}'.trim();
    if (int.tryParse('${data['previewVersion']}') != 1 ||
        !flag('provisional') ||
        !flag('closureProofPending') ||
        sequence == null ||
        sequence < 0 ||
        !const {'COMPLETED', 'FAILED', 'UNCLEAR'}.contains(outcome)) {
      return null;
    }
    return CallOutcomePreview(
      sequence,
      outcome,
      '${data['headline'] ?? ''}'.trim(),
      '${data['detail'] ?? ''}'.trim(),
    );
  }
}
