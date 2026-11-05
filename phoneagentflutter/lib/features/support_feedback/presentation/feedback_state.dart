import '../domain/feedback.dart';

class FeedbackState {
  const FeedbackState({
    this.description = '',
    this.contact = '',
    this.includeLogs = false,
    this.images = const [],
    this.busy = false,
    this.processing = false,
    this.success = false,
    this.error = '',
  });
  final String description, contact, error;
  final bool includeLogs, busy, processing, success;
  final List<FeedbackImage> images;
  bool get hasDraft =>
      description.isNotEmpty ||
      contact.isNotEmpty ||
      images.isNotEmpty ||
      includeLogs;
  FeedbackState copy({
    String? description,
    String? contact,
    bool? includeLogs,
    List<FeedbackImage>? images,
    bool? busy,
    bool? processing,
    bool? success,
    String? error,
  }) => FeedbackState(
    description: description ?? this.description,
    contact: contact ?? this.contact,
    includeLogs: includeLogs ?? this.includeLogs,
    images: images ?? this.images,
    busy: busy ?? this.busy,
    processing: processing ?? this.processing,
    success: success ?? this.success,
    error: error ?? this.error,
  );
}
