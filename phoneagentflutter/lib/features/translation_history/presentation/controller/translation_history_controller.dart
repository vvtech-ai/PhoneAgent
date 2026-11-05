import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/record_time.dart';
import '../../domain/translation_history.dart';

class TranslationHistoryState {
  const TranslationHistoryState({
    this.loading = false,
    this.failed = false,
    this.content,
  });
  final bool loading, failed;
  final TranslationHistoryContent? content;
}

class TranslationRow {
  const TranslationRow(this.mine, this.primary, this.secondary);
  final bool mine;
  final String primary, secondary;
}

class TranslationHistoryContent {
  const TranslationHistoryContent(
    this.title,
    this.phone,
    this.time,
    this.duration,
    this.rows,
    this.recordingAvailable,
  );
  final String title, phone, time, duration;
  final List<TranslationRow> rows;
  final bool recordingAvailable;
  factory TranslationHistoryContent.from(TranslationHistory value) {
    final name = value.targetName.trim();
    final named =
        name.isNotEmpty && !{'未知联系人', '未知对象', '目标对象', '对方'}.contains(name);
    final seconds = value.durationMillis ~/ 1000;
    String pad(int value) => value.toString().padLeft(2, '0');
    final duration = seconds >= 3600
        ? '${pad(seconds ~/ 3600)}:${pad(seconds ~/ 60 % 60)}:${pad(seconds % 60)}'
        : '${pad(seconds ~/ 60)}:${pad(seconds % 60)}';
    final rows = <TranslationRow>[];
    for (final t in value.transcripts) {
      if (t.sourceText.trim().isEmpty && t.translatedText.trim().isEmpty) {
        continue;
      }
      final translated =
          t.translatedLanguage.toLowerCase() ==
              value.myLanguage.toLowerCase() &&
          t.sourceLanguage.toLowerCase() != value.myLanguage.toLowerCase();
      final primary = translated ? t.translatedText : t.sourceText;
      final secondary = translated ? t.sourceText : t.translatedText;
      String family(String language) =>
          language.trim().replaceAll('_', '-').split('-').first.toLowerCase();
      final duplicate =
          primary.trim() == secondary.trim() ||
          (family(t.sourceLanguage).isNotEmpty &&
              family(t.sourceLanguage) == family(t.translatedLanguage));
      rows.add(
        TranslationRow(
          {'local', 'user'}.contains(t.sourceLeg.toLowerCase()),
          primary,
          primary.trim().isNotEmpty && duplicate ? '' : secondary,
        ),
      );
    }
    return TranslationHistoryContent(
      named
          ? name
          : value.phoneNumber.isEmpty
          ? '未知号码'
          : value.phoneNumber,
      named ? value.phoneNumber : '',
      _time(value.connectedAt),
      duration,
      List.unmodifiable(rows),
      value.recording != null || value.localRecordingAvailable,
    );
  }

  static String _time(String raw) => recordTimeLabel(raw);
}

class TranslationHistoryController
    extends StateNotifier<TranslationHistoryState> {
  TranslationHistoryController(this._repository, this.callId)
    : super(const TranslationHistoryState());
  final TranslationHistoryRepository _repository;
  final String callId;
  int _generation = 0;
  Future<void> load() async {
    if (state.loading) return;
    final generation = ++_generation;
    state = TranslationHistoryState(loading: true, content: state.content);
    try {
      final detail = await _repository.load(callId);
      if (!mounted || generation != _generation) return;
      state = TranslationHistoryState(
        content: TranslationHistoryContent.from(detail),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        state = TranslationHistoryState(failed: true, content: state.content);
      }
    }
  }
}
