import 'dart:async';
import 'domestic_sip_media.dart';
import 'domestic_translation_model.dart';
import 'domestic_translation_processor.dart';
import 'sip_lease.dart';
import 'sip_rtp_transport.dart';
import 'sip_sdp.dart';
import 'sip_transactions.dart';
import 'translation_call_plan.dart';

abstract interface class DomesticSipConnection {
  Future<SipAudioEndpoint> start();
  Future<void> holdUntilEnded();
  Future<void> sendInfo(String digit);
  SipRtpTransport media(SipAudioEndpoint endpoint);
  Future<void> close();
}

typedef DomesticSipConnectionFactory =
    Future<DomesticSipConnection> Function(
      SipLease lease,
      TranslationCallPlan plan,
      void Function(SipCallPhase) onPhase,
    );

typedef DomesticTranslationProcessorFactory =
    DomesticTranslationProcessor Function(
      DomesticModelConfiguration config,
      void Function(DomesticTranslationLeg, DomesticModelEvent) onEvent,
      bool Function() isCurrent,
    );

typedef DomesticSipMediaFactory =
    FutureOr<DomesticSipMedia> Function(
      SipRtpTransport rtp,
      SipAudioEndpoint endpoint,
      DomesticTranslationProcessor models,
      bool Function() isCurrent,
      void Function(String) onFailure,
    );
