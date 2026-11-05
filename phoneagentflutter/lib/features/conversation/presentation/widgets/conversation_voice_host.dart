import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/conversation_voice_providers.dart';
import '../../../../app/conversation_providers.dart';
import '../../../../app/agent_context_providers.dart';
import '../../../../app/online_entry_providers.dart';
import '../../../settings/domain/network_availability.dart';
import '../controller/conversation_state.dart';
import 'voice_composer_binding.dart';
import '../../../../app/task_voice_preference_providers.dart';

class ConversationVoiceHost extends ConsumerStatefulWidget {
  const ConversationVoiceHost({
    super.key,
    required this.entry,
    required this.builder,
    this.inputBlocked = false,
  });
  final ConversationEntry entry;
  final bool inputBlocked;
  final Widget Function(VoiceComposerBinding) builder;
  @override
  ConsumerState<ConversationVoiceHost> createState() =>
      _ConversationVoiceHostState();
}

class _ConversationVoiceHostState extends ConsumerState<ConversationVoiceHost>
    with WidgetsBindingObserver {
  late final void Function() _unbindPermissionResume;
  late final StreamSubscription<NetworkAvailability> _networkSubscription;
  bool _postFrameScheduled = false;
  bool _interrupted = false;
  bool _recoveryPending = false;
  bool _recoveryScheduled = false;
  bool? _routeWasCurrent;
  NetworkAvailability? _lastAvailability;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final conversation = ref.read(
      conversationControllerProvider(widget.entry).notifier,
    );
    _unbindPermissionResume = ref
        .read(taskLocationPermissionProvider)
        .bindResume(
          widget.entry.sessionId,
          conversation.permissionResume,
          () => conversation.speech?.begin(sessionId: widget.entry.sessionId),
        );
    _networkSubscription = ref
        .read(networkAvailabilityEventsProvider)
        .watch()
        .listen(_networkChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRecovery();
  }

  void _networkChanged(NetworkAvailability availability) {
    if (!mounted) return;
    final changed = _lastAvailability != availability;
    _lastAvailability = availability;
    if (!changed || availability != NetworkAvailability.available) return;
    // A shared broadcast stream may have emitted "unavailable" before this page subscribed.
    _recoveryPending = true;
    _scheduleRecovery();
  }

  bool get _visible =>
      mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent == true;

  void _scheduleRecovery() {
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent == true;
    if (_routeWasCurrent == false && routeIsCurrent) {
      _recoveryPending = true;
    }
    _routeWasCurrent = routeIsCurrent;
    if (!_recoveryPending || _recoveryScheduled || !_visible) return;
    _recoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoveryScheduled = false;
      if (!_recoveryPending || !_visible) return;
      _recoveryPending = false;
      final conversation = ref.read(
        conversationControllerProvider(widget.entry).notifier,
      );
      if (conversation.isOpen) {
        unawaited(conversation.resumeAfterInterruption());
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final conversation = ref.read(
      conversationControllerProvider(widget.entry).notifier,
    );
    conversation.speech?.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      conversation.permissionResume.resume();
      if (_interrupted) {
        _interrupted = false;
        _recoveryPending = true;
      }
      _scheduleRecovery();
    } else if (state == AppLifecycleState.inactive) {
      _interrupted = true;
      conversation.permissionResume.inactive();
    } else {
      if (state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused) {
        _interrupted = true;
      }
      conversation.permissionResume.background(
        preflightPending: ref
            .read(taskLocationPermissionProvider)
            .isPending(widget.entry.sessionId),
      );
    }
    if (state != AppLifecycleState.resumed) {
      ref.read(taskVoiceGuideProvider(widget.entry)).cancel();
      unawaited(ref.read(conversationVoiceProvider(widget.entry)).cancel());
    }
    // A focus-only permission dialog preserves eligibility when no narration
    // has started. Active narration stops on iOS/Android inactive as well.
    if (state == AppLifecycleState.inactive &&
            conversation.speech?.isActive == true ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        ref
            .read(conversationControllerProvider(widget.entry).notifier)
            .speech
            ?.pauseForLifecycle(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unbindPermissionResume();
    unawaited(_networkSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleRecovery();
    final controller = ref.watch(conversationVoiceProvider(widget.entry));
    final conversation = ref.watch(
      conversationControllerProvider(widget.entry).notifier,
    );
    final speech = conversation.speech;
    final preference = ref.watch(taskVoicePreferenceProvider);
    final guide = ref.watch(taskVoiceGuideProvider(widget.entry));
    final state = ref.watch(conversationControllerProvider(widget.entry));
    return ListenableBuilder(
      listenable: Listenable.merge([controller, speech, guide]),
      builder: (context, _) {
        if (!_postFrameScheduled) {
          _postFrameScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _postFrameScheduled = false;
            if (mounted) {
              final current = ref.read(
                conversationControllerProvider(widget.entry),
              );
              if (preference.ready &&
                  !widget.inputBlocked &&
                  current.canSend &&
                  controller.state.canPress &&
                  ModalRoute.of(context)?.isCurrent == true) {
                final prompt = conversation.apology?.voice.prompt;
                if (prompt != null) {
                  speech?.speakLocalPrompt(prompt.id, prompt.text);
                } else if (conversation.apology == null) {
                  speech?.speakOpening(
                    current.entry.opening,
                    restored:
                        current.entry.restore || current.messages.isNotEmpty,
                  );
                }
              }
              guide.ready(
                conversation.isOpen &&
                    !widget.inputBlocked &&
                    current.voiceMode &&
                    current.canSend &&
                    ModalRoute.of(context)?.isCurrent == true &&
                    speech?.isActive != true &&
                    controller.state.canPress,
              );
            }
          });
        }
        return widget.builder(
          VoiceComposerBinding(
            state: controller.state,
            speechStatus: speech?.status ?? '',
            canInterruptReply: speech?.isActive == true,
            onStopSpeech: () {
              unawaited(speech?.pause());
            },
            aiSpeechEnabled: preference.speechEnabled,
            preferenceNotice: preference.notice,
            onToggleSpeech: () {
              if (!preference.ready) {
                unawaited(preference.load());
              } else if (preference.notice.contains('保存失败')) {
                preference.retrySpeechSave();
              } else {
                unawaited(speech?.interrupt());
                preference.speech(!preference.speechEnabled);
              }
            },
            guideHint: state.voiceMode && speech?.isActive != true
                ? guide.hint
                : '',
            onGesturePress: guide.press,
            onGestureRelease: guide.release,
            onGestureCancel: guide.cancel,
            onPress: () {
              if (widget.inputBlocked) return;
              conversation.interruptReplyForInput();
              unawaited(controller.press());
            },
            onRelease: controller.release,
            onCancel: () => unawaited(controller.cancel()),
          ),
        );
      },
    );
  }
}
