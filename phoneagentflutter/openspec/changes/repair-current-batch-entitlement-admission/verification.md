# Bug 23763 拒绝后的权益刷新

- 新增独立BatchEntitlementRefreshGateway，只识别结构化BATCH_CONTACT_LIMIT、BATCH_CONCURRENCY_LIMIT、BATCH_ENTITLEMENT_LIMIT。一次请求只使承载商品与当前会员的catalogControllerProvider失效一次，不自动重试命令。
- 保留原事件对象、错误及堆栈，既有会员拒绝文案和TTS仍使用原流程；取消、释放和登录替换后不刷新。刷新异常不替换原拒绝。网关不watch商品状态，刷新不重建活动任务。
- 红灯：透明转发的原行为下9项测试4项失败，3种拒绝及结构化错误未触发刷新。
- 绿灯：12文件83项Flutter定向通过；覆盖新适配器、拒绝文案/历史/TTS、真实Dio传输、商品局部读取、批量确认/拒绝、离开页面继续任务与账号替换。分两批命令：
  - `flutter test test/features/conversation/batch_entitlement_refresh_gateway_test.dart test/features/conversation/membership_denial_reply_test.dart test/features/conversation/membership_denial_history_test.dart test/features/conversation/voice/membership_denial_speech_test.dart test/features/conversation/agent_gateway_test.dart test/features/commerce/catalog_controller_test.dart test/features/commerce/catalog_partial_load_test.dart`：49项。
  - `flutter test test/features/conversation/batch_confirmation_rejection_test.dart test/features/conversation/batch_conversation_lifecycle_test.dart test/features/conversation/detached_batch_provider_test.dart test/features/conversation/detached_batch_streams_test.dart test/features/conversation/batch_confirmation_test.dart`：34项。
- Flutter3.32.0 analyze无问题，OpenSpec207项通过，diff与UTF-8检查通过。
- 保留拉取到的cbf78e11中iOS可信来电与账号中文输入修改。本次无平台/支付/权限/版本变更，保持1.0.52 (45)，未打包、未安装、未触发真实外呼。需配合后端SDK/SSE更新后验收真实旧账号。
