# 注销退出连续 loading 验证

日期：2026-10-28；仓库PhoneAgent，分支feature/test_v1.8.0，基线909d47409072dd19176bbd5fd391167c6ac3cd70。进入时工作区干净；只修改本次Flutter展示、接线、预览测试端口及文档，不改SDK/后端/原生/依赖。

## 源码与回放

- 新增最终确认→慢提交→慢存储→卸载旧账号页→慢草稿清理→登录的真实PhoneAgentApp/GoRouter连续帧回放；修改前两平台均期望1个CircularProgressIndicator、实际0，先RED。
- NativeLoadingOverlay复用原支付遮罩/Card/间距/进度组件；PurchaseLoadingOverlay继续传原“支付处理中…”文案。注销不传message，只有一个spinner，无阶段提示文本。
- CancellationExitController按账号、登录代次、操作token持有maskedPhone/cooldown等无权限静态展示信息，不持有验证码、验证/查询凭证、旧Widget或订阅，不截图、不写入持久化。
- CancellationExitHost在根Navigator上方保留原验证码页无交互外观，使用独立UI控制器；旧AccountRoute在草稿清理开始前已真实卸载，加载仍在。
- SessionNavigationHost保持原卸载/帧确认/清理顺序；只在注销阶段给出不透明释放占位，普通退出默认不变。
- 成功后保持到新登录页面首帧构建/布局完成，再撤去loading；登录中央成功notice沿用原显示与自动消失。无固定延时。
- 已受理清理失败时停止spinner，保留原业务屏障和退出重试；重试复用原静态展示和新操作token，只调用退出清理，不重复申请。
- Root host始终保留同一子树结构，切换loading不重新挂载旧导航。静态页位于根builder，独立Overlay.wrap满足共用Header Tooltip的UI宿主要求，无第二业务Navigator。

## 自动结果

固定Flutter3.32.0/Dart3.8.0，flutter analyze --no-pub：无问题。

定向组合217项通过，覆盖：account_cancellation全部测试；settings的account_route、auto_verification、entry_confirmation、confirmation_layout/ime、cooling_period_display；settings_account_shell；auth_controller/session_controller/session_release；task_draft_cleanup；native_notice/queue/keyboard；ios_payment_phase；membership_route_v2/payment_feedback。

其中新增9项：两平台逐帧慢退出2项、提交失败/未知2项、已受理清理失败及重试1项、账号替换迟到提交1项、临时owner/旧token/销毁回调隔离3项。断言加载唯一且无进度文本、返回不产生副作用、旧页真实dispose、请求立即失效、清理完成移除spinner及成功notice消失。

扩大导航回归13项通过、3项失败：auth_session_widget_test的iOS登录恢复，以及shell_settings_platform_back_test的iOS字体1.0/2.0。三项均为15秒IosPaymentRuntime.boundRecovery计时器残留。在新建隔离临时目录git archive基线909d474提取未修改源码、使用同工具链/依赖和相同两个文件，3通过/同名3失败且相同15秒调用栈复现；未修改支付实现或删断言，不将三项算通过。

本地输出：/tmp/phoneagent-exit-loading-red.log、green.log、cases.log、analyze.log、regression.log、navigation.log、baseline.log（同phoneagent-exit-loading前缀）。日志不提交。

## 边界

- 非全量测试；未打包安装，未取得Android/iOS真机逐帧画面，不能称现场黑屏已实测消失。
- OpenSpec CLI当前PATH不可用，执行文档结构/链接/UTF-8及diff检查，未声称strict通过。
- 本次不修改注销接口、冷静期、权益或账号权限；不发送短信、不执行真实注销/部署/数据库操作。
- 未提交或推送；保留当前分支，待实际验收后再归档。
