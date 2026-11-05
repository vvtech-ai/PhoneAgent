import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../domain/translation_dial_request.dart';
import 'translation_call_controller.dart';
import '../../domain/sip/translation_call_plan.dart';
import '../../domain/translation_call_finished.dart';

/// Entry composition only. Production supplies fully admitted account/media
/// dependencies; preview composition replaces external services, not this route.
class TranslationDialSessionBinding {
  const TranslationDialSessionBinding({
    required this.create,
    this.header,
    this.createDomestic,
  });
  final FutureOr<TranslationCallController> Function(
    TranslationCallPlan,
    TranslationCallContext,
  )?
  createDomestic;
  final FutureOr<TranslationCallController> Function(TranslationDialRequest)
  create;
  final Widget Function(BuildContext, TranslationCallController)? header;
}
