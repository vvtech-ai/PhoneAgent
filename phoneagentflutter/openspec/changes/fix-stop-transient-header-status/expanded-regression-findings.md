# 扩大回归尝试的失败明细

这轮测试在实现和远端合并期间启动，后来主动结束旧进程，最后进度为 6993 通过、2 跳过、95 失败；不能作为固定最终源码的全量结论。最终源码另以串行定向回归验收。失败明细仅保留测试名称，不保留业务日志或用户数据。

未加入本次修复的干净提交 `2529c927c6e0abe3983c8f23e7cf600e81401f72` 分批复验：89 项同名失败重现；5 项本次实现过程中的失败已修复并纳入最终定向回归；1 项 UDP 回环用例在干净基线单独运行通过，完整尝试曾失败，根因未确定，不据此修改网络实现。

## 干净基线重现的既有失败（89）

- `test/architecture_test.dart`：Handwritten Dart files fit the default 500 line budget
- `test/extended_device_stage_test.dart`：extended device journey preflight Size(375.0, 667.0) (variant: TargetPlatform.android)
- `test/extended_device_stage_test.dart`：extended device journey preflight Size(375.0, 667.0) (variant: TargetPlatform.iOS)
- `test/extended_device_stage_test.dart`：extended device journey preflight Size(393.0, 820.0) (variant: TargetPlatform.android)
- `test/extended_device_stage_test.dart`：extended device journey preflight Size(393.0, 820.0) (variant: TargetPlatform.iOS)
- `test/features/calls/continuous_task_orchestration_test.dart`：CONFIRM-01 HISTORY-01: 1 calls retain prompts, identities and narration
- `test/features/calls/continuous_task_orchestration_test.dart`：CONFIRM-01 HISTORY-01: 2 calls retain prompts, identities and narration
- `test/features/calls/continuous_task_orchestration_test.dart`：ENTRY-06 VOICE-01: tool-only history never invents a spoken prompt
- `test/features/calls/conversation_call_flow_test.dart`：late call result refreshes task state once
- `test/features/calls/conversation_structured_failure_test.dart`：reported outcome with committed result closes the unregistered observation
- `test/features/conversation/batch_receipt_media_parity_test.dart`：TargetPlatform.android nested=false exposes native batch media and settlements
- `test/features/conversation/batch_receipt_media_parity_test.dart`：TargetPlatform.android nested=true exposes native batch media and settlements
- `test/features/conversation/batch_receipt_media_parity_test.dart`：TargetPlatform.iOS nested=false exposes native batch media and settlements
- `test/features/conversation/batch_receipt_media_parity_test.dart`：TargetPlatform.iOS nested=true exposes native batch media and settlements
- `test/features/conversation/call_receipt_widget_test.dart`：readable fallback includes returned fields, rates and recognized dialogue only
- `test/features/conversation/call_receipt_widget_test.dart`：receipt is accessible in existing message layout without dial buttons
- `test/features/conversation/conversation_receipt_revision_test.dart`：TargetPlatform.android same message visible updates return to tail
- `test/features/conversation/conversation_receipt_revision_test.dart`：TargetPlatform.iOS same message visible updates return to tail
- `test/features/conversation/conversation_receipt_revision_test.dart`：batch visible values change while hidden fields preserve history
- `test/features/conversation/conversation_receipt_revision_test.dart`：running summary and empty billing have no displayed change
- `test/features/conversation/conversation_single_receipt_revision_test.dart`：TargetPlatform.android same message single update returns to tail
- `test/features/conversation/conversation_single_receipt_revision_test.dart`：TargetPlatform.iOS same message single update returns to tail
- `test/features/conversation/detached_batch_streams_test.dart`：detached stream drains without UI or tool callbacks until done
- `test/features/conversation/native_conversation_tail_test.dart`：TargetPlatform.android new content and keyboard follow tail at 1.0
- `test/features/conversation/native_conversation_tail_test.dart`：TargetPlatform.android new content and keyboard follow tail at 2.0
- `test/features/conversation/native_conversation_tail_test.dart`：TargetPlatform.iOS new content and keyboard follow tail at 1.0
- `test/features/conversation/native_conversation_tail_test.dart`：TargetPlatform.iOS new content and keyboard follow tail at 2.0
- `test/features/conversation/restored_batch_confirmation_focus_test.dart`：TargetPlatform.android live long pending card aligns its top without sending
- `test/features/conversation/restored_batch_confirmation_focus_test.dart`：TargetPlatform.android restored long pending card aligns its top without sending
- `test/features/conversation/restored_batch_confirmation_focus_test.dart`：TargetPlatform.iOS live long pending card aligns its top without sending
- `test/features/conversation/restored_batch_confirmation_focus_test.dart`：TargetPlatform.iOS restored long pending card aligns its top without sending
- `test/features/conversation/terminal_receipt_overlay_parity_test.dart`：ledger terminal retains same-attempt live media and zero billing
- `test/features/settings/voice_transport_preview_test.dart`：gateway interaction without native media at 320.0
- `test/features/settings/voice_transport_preview_test.dart`：gateway interaction without native media at 390.0
- `test/features/settings/voice_transport_preview_test.dart`：gateway interaction without native media at 430.0
- `test/features/translation/cross_border_translation_dial_test.dart`：TargetPlatform.android dial cross-border cancel then continue once
- `test/features/translation/cross_border_translation_dial_test.dart`：TargetPlatform.android presets cross-border cancel then continue once
- `test/features/translation/cross_border_translation_dial_test.dart`：TargetPlatform.iOS dial cross-border cancel then continue once
- `test/features/translation/cross_border_translation_dial_test.dart`：TargetPlatform.iOS presets cross-border cancel then continue once
- `test/features/translation/domestic_model_quality_test.dart`：domestic refresh drives all pill states TargetPlatform.android
- `test/features/translation/domestic_model_quality_test.dart`：domestic refresh drives all pill states TargetPlatform.iOS
- `test/features/translation/domestic_model_quality_test.dart`：no domestic requests for CN/false/true
- `test/features/translation/domestic_model_sheet_test.dart`：directory choice persists without account setting TargetPlatform.android/1.0
- `test/features/translation/domestic_model_sheet_test.dart`：directory choice persists without account setting TargetPlatform.android/2.0
- `test/features/translation/domestic_model_sheet_test.dart`：directory choice persists without account setting TargetPlatform.iOS/1.0
- `test/features/translation/domestic_model_sheet_test.dart`：directory choice persists without account setting TargetPlatform.iOS/2.0
- `test/features/translation/domestic_model_sheet_test.dart`：directory failure is explicit and summary retry recovers
- `test/features/translation/domestic_model_sheet_test.dart`：same protocol models have independent selectable IDs
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.android/1.0/Size(320.0, 480.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.android/1.0/Size(390.0, 844.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.android/2.0/Size(320.0, 480.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.android/2.0/Size(390.0, 844.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.iOS/1.0/Size(320.0, 480.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.iOS/1.0/Size(390.0, 844.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.iOS/2.0/Size(320.0, 480.0)
- `test/features/translation/native_translation_model_panel_test.dart`：four native options TargetPlatform.iOS/2.0/Size(390.0, 844.0)
- `test/features/translation/translation_access_pages_test.dart`：CN international prefix uses domestic model sheet and never starts an overseas call
- `test/features/translation/translation_access_pages_test.dart`：developer country simulation reaches dialer without changing trusted CN
- `test/features/translation/translation_diagnostics_binding_test.dart`：new components and stages survive Journal reload and ZIP; session and extra fields sanitized
- `test/features/translation/translation_pages_test.dart`：empty number opens presets then rejects without any call
- `test/features/translation/translation_pages_test.dart`：formal translation action respects offline without system fallback
- `test/features/translation/translation_pages_test.dart`：leaving during async preparation disposes late controller without start
- `test/features/translation_history/local_translation_recording_test.dart`：history joins ongoing encode even when SDK duration differs
- `test/features/voice_clone/clone_entitlement_route_test.dart`：account change while upgrading cannot refresh or enter the old clone flow
- `test/features/voice_clone/clone_entitlement_route_test.dart`：return without upgrade checks again and still blocks creation
- `test/features/voice_clone/clone_entitlement_route_test.dart`：upgrade opens membership and returning reloads entitlement
- `test/settings_account_shell_test.dart`：settings account native flow returns to login TargetPlatform.android (variant: TargetPlatform.android)
- `test/settings_account_shell_test.dart`：settings account native flow returns to login TargetPlatform.iOS (variant: TargetPlatform.iOS)
- `test/shell_attachment_workbench_test.dart`：formal attachments, history and session isolation 320.0
- `test/shell_attachment_workbench_test.dart`：formal attachments, history and session isolation 430.0
- `test/shell_contacts_workbench_test.dart`：contact detail to formal task and restored conversation 320.0
- `test/shell_contacts_workbench_test.dart`：contact detail to formal task and restored conversation 430.0
- `test/shell_developer_workbench_test.dart`：formal developer flow is isolated and continuous 320.0
- `test/shell_developer_workbench_test.dart`：formal developer flow is isolated and continuous 430.0
- `test/shell_log_report_workbench_test.dart`：settings log flow retries only failed operation 320.0
- `test/shell_log_report_workbench_test.dart`：settings log flow retries only failed operation 430.0
- `test/shell_permission_workbench_test.dart`：permission result, restore and login isolation 320.0
- `test/shell_permission_workbench_test.dart`：permission result, restore and login isolation 430.0
- `test/shell_receipt_workbench_test.dart`：receipt audio and per-target feedback through formal routes 320.0
- `test/shell_receipt_workbench_test.dart`：receipt audio and per-target feedback through formal routes 430.0
- `test/shell_translation_workbench_test.dart`：shell translation confirmation call records and reset 320.0
- `test/shell_translation_workbench_test.dart`：shell translation confirmation call records and reset 390.0
- `test/shell_translation_workbench_test.dart`：shell translation confirmation call records and reset 430.0
- `test/shell_unified_dialer_test.dart`：formal entries use one dialer and preserve draft and unlock (variant: TargetPlatform.android)
- `test/shell_unified_dialer_test.dart`：formal entries use one dialer and preserve draft and unlock (variant: TargetPlatform.iOS)
- `test/shell_workbench_test.dart`：shared shell continuous flow and reset at 320.0
- `test/shell_workbench_test.dart`：shared shell continuous flow and reset at 430.0
- `test/ui_consistency_stage_test.dart`：formal first flow preserves drafts and returns (variant: TargetPlatform.android)
- `test/ui_consistency_stage_test.dart`：formal first flow preserves drafts and returns (variant: TargetPlatform.iOS)

## 本次修复后重新验收的失败（5）

- `test/features/conversation/call_confirmation_feedback_test.dart`：result wait feedback ignores old thinking: current=true
- `test/features/conversation/stop_transient_header_status_test.dart`：TargetPlatform.android single=false stop progress has no waiting gap
- `test/features/conversation/stop_transient_header_status_test.dart`：TargetPlatform.android single=true stop progress has no waiting gap
- `test/features/conversation/stop_transient_header_status_test.dart`：TargetPlatform.iOS single=false stop progress has no waiting gap
- `test/features/conversation/stop_transient_header_status_test.dart`：TargetPlatform.iOS single=true stop progress has no waiting gap

## 独立基线复验通过、完整尝试曾失败（1）

- `test/features/translation/udp_sip_rtp_transport_test.dart`：loopback filters other ports and malformed packets and sends negotiated peer

最终源码额外串行运行同一文件时该用例再次 1 秒超时，另一用例通过；同批之前的 16 个文件 127 项全部通过。UDP 失败未确定根因；不声称最终包含该文件的命令通过，不以放宽超时或修改业务代码掩盖。
