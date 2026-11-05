# 公共 Toast 队列验证记录

日期：2026-10-16。当前分支 codex/dev_zys，HEAD 987dc1d7；基于当前工作区小范围修改，实施阶段不切分支、不提交推送；用户随后授权仅本批创建本地commit，不推送。其他克隆/道歉/模型及交付文档未提交修改保留。

## 实现范围
- lib/core/design/native_notice.dart：FIFO、自然结束推进、主动清空、不同Overlay隔离、旧销毁回调身份校验；212行，仍为单一公共提示职责。
- lib/app/session_navigation_host.dart：账号释放及宿主销毁清空提示；73行。
- test/native_notice_queue_test.dart：9项，包括Android/iOS主题下依次展示、不同寿命、淡出中追加、空消息、清空后立即新增、销毁/更换Overlay、普通导航、账号释放/token刷新、宿主销毁。
- test/features/points/points_session_host_test.dart：新登录和恢复登录均以响应735/65验证顺序、4秒寿命、重建不重播。原有生命周期用例保持。
- test/native_notice_test.dart 和 test/features/invite/native_invite_notice_navigation_test.dart：连续触发断言更新为排队，仍验证点击穿透、邀请返回记录及已销毁页面不接收晚到反馈。

保留现有所有UI参数、接口及文案；邀请奖励确认弹窗独立；不新增登录成功提示或改动服务端赠送逻辑。

## 自动验证
使用现有 /Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter 固定SDK，不升级依赖。实际执行：

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded \
  test/native_notice_queue_test.dart test/native_notice_test.dart \
  test/native_notice_keyboard_test.dart test/features/points \
  test/features/auth/session_release_test.dart \
  test/features/auth/auth_session_widget_test.dart \
  test/features/auth/login_agreement_feedback_test.dart \
  test/features/invite/native_invite_notice_navigation_test.dart \
  test/features/invite/invite_page_test.dart \
  test/features/invite/invite_entry_notice_host_test.dart \
  test/features/invite/v67_invite_reward_test.dart \
  test/features/call_models/call_model_selection_feedback_test.dart \
  test/features/translation/translation_model_sheet_test.dart \
  test/features/translation/domestic_model_sheet_lifecycle_test.dart \
  test/features/contacts/contact_remark_notice_test.dart \
  test/shell_feedback_ports_test.dart test/architecture_test.dart
openspec validate --all
git diff --check
```

结果：206项定向测试全部通过，约17秒；analyze无问题，11秒；OpenSpec165项全部通过，diff检查通过。OpenSpec使用本机现有Node运行缓存CLI，未安装或更新工具。

测试开发中修正了三个问题：180ms精确动画边界需跨过1ms才稳定触发结束；全局平台override改为ThemeData避免测试框架变量泄漏；积分测试新增dart:async导入初次误插文件末尾，读回后移至顶部。修正后上述最终完整定向集合通过；无未解决失败。

## 边界与待验
测试覆盖Widget和合成端口；不代表实体设备或真实积分发放验收。未执行真实短信、登录、认证、外呼、支付，不打包安装；未更改后端、签名、环境、版本或依赖。双端设备实际视觉验收待办保持，change不归档。共享tasks和问题日志仅更新本批记录，保留原内容。
