# 研发验证 2026-10-20

## 基线与范围

Flutter `codex/dev`，修改前 `afd919df`；旧App `feature/test_v1.6.0@8f23592` 与原项目 `origin/test/v66.0.3@a0bedb12` 只读核对。四个旧草稿核心文件在两版本一致：账号/任务归属、成功发送清除、真正未受理失败恢复、删除/登出清理。旧项目的既有未提交内容未改动。

仅Flutter：草稿、拨前翻译展示与选择、播报暂停分类；无Java、接口、数据库、计费规则或供应商SDK修改。不恢复用户取消的结束账单页，不处理已暂缓的翻译断网通话。

## 实现与失败证据

- 草稿：先观察发送后立即重进仍恢复已发文字的失败；改为入口接受时清持久化，临时副本只供真正未受理失败恢复。版本守卫保护后续新输入。按原scope键兼容，账号共享队列防新页面读越过旧删除；索引和reset标记支持精确任务、当前账号清理及旧未索引数据惰性清理，iOS不使用readAll/deleteAll。
- 受理证据：有效本轮响应不再只依赖USER_TURN_ACCEPTED账本；其它command的迟到账本不能证明本轮已受理。独立双轮探针及正式控制器反例覆盖。集合由消息存储持有，主编排器仅增加一行只读getter，523行准确例外见file_exceptions.md。
- 生命周期：页面先释放再清账号，token刷新不重建草稿清理owner。独立复核先复现清理异常导致空白宿主、远端删除成功却本地提示失败，应用清理适配器隔离异常，只记固定无正文日志。存储不可用时不能保证实际删除。
- 翻译：先RED验证底部积分位置、金色星标、有效同语种保留和拨号Toast；真实入口使用正式translationAccessProvider。积分灰色10号/14行高，按钮下方7间距；320×568两倍字号及Android/iOS主题几何检查通过。有效手选保留，仅无效默认回退避同语；country/history显式同步取国家默认，拨号时语言提示优先号码警告。国家页立即进入，后台刷新保留旧列表；不可用模型不推荐，地区原因优先于后台长说明。
- 独立复核补两类翻译RED：迟到定位覆盖手选ja、非空说明遮蔽不可用原因，均修复后GREEN。
- 播报：首批13处RED，正常相册/生命周期/音频焦点取消与真实供应商/传输/输出/停止故障分开；暂停显示“播报已暂停，可继续交流”，故障仍失败。generation防旧回调污染；新轮次/录音/静音清暂停；不重播、不改变任务状态。真实附件菜单到pick前的双端页面接线已测试。

## 最终命令与结果

固定Flutter3.32.0；最终统一定向命令26文件 **189通过，0失败**：

```powershell
flutter test --no-pub --reporter expanded `
  test/features/conversation/task_draft_controller_test.dart `
  test/features/conversation/task_draft_storage_test.dart `
  test/features/conversation/task_draft_cleanup_test.dart `
  test/features/conversation/conversation_controller_test.dart `
  test/features/auth/session_release_test.dart `
  test/native_notice_queue_test.dart `
  test/features/tasks/task_pagination_test.dart `
  test/features/tasks/task_mutation_projection_test.dart `
  test/features/conversation/voice/tts_pause_classification_test.dart `
  test/features/conversation/voice/speech_pause_controller_test.dart `
  test/features/conversation/voice/conversation_pause_page_test.dart `
  test/features/conversation/v66_conversation_status_test.dart `
  test/features/conversation/tts_composer_control_test.dart `
  test/features/attachments/ocr_route_test.dart `
  test/features/conversation/voice/permission_reply_lifecycle_test.dart `
  test/features/translation/translation_native_details_test.dart `
  test/features/translation/translation_language_alignment_test.dart `
  test/features/translation/translation_dialer_parity_test.dart `
  test/features/translation/translation_model_sheet_test.dart `
  test/features/translation/translation_phone_format_flow_test.dart `
  test/features/translation/translation_setup_test.dart `
  test/core/config/app_config_test.dart `
  test/features/auth/dio_auth_gateway_test.dart `
  test/features/conversation/conversation_navigation_test.dart `
  test/features/home/shell_navigation_test.dart `
  test/features/trusted_caller/trusted_identity_overlay_app_test.dart
```

`flutter analyze --no-pub` 全仓无问题（24.9秒）；当前change严格校验、git diff --check、UTF-8/中文读回通过。所有本次修改源码满足已有准确文件上限。

独立审查草稿、speech、translation最终均APPROVE，无剩余P1/P2；修复依据包含仓库外真实控制器/存储及页面探针，不以仅对实现的文本匹配代替行为测试。独立及扩大集合与最终集合有重叠，不相加当作唯一测试数。

## 扩大范围发现的基线问题

- voice扩大集合273通过/1失败：`voice_input_page_test.dart:71` 在播报中查找send-text。将完整HEAD `afd919df` 源码导出到仓库外，固定3.32及同依赖单跑，仍0通过/1失败、同一断言；不为本次改旧测试。
- translation扩大直接回归58通过/6失败：原domestic_model_sheet_test对无倍率semantics的既有断言，与当前summary含倍率不符。本批未修改该summary或这些断言，临时测试调整已恢复。
- architecture测试3通过/1失败：未修改的`domestic_sip_media.dart`已有504行，HEAD与工作树字节相同；原默认上限500。只复核本批Controller只读接口523例外，不放宽无关文件限制。

这些扩大集合不作为全量通过。本批没有运行全仓全部测试。

## 待真机验收与交付边界

Android/iOS真实相册、保护沙盒、后台音路和真实外呼待验；主题/通道模拟测试不等于手机验收。没有发起真实短信、认证、支付或电话。提交推送、打包前再次拉取、签名包版本及产物检查只在交付对话记录，不新增纯打包回执或打包日志提交。
