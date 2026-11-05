## 修改与范围

新增 `lib/core/design/native_page_header.dart`：NativePageHeader、NativePageAppBar；同步布局测量两侧，保留最少24标题空间，标题单行末尾省略。页面持有返回与操作状态；组件无网络、存储和业务状态。原NativeDetailHeader不变。

| 入口 | 完整页范围 | 背景 / 状态保留 |
| --- | --- | --- |
| 设置→记忆 | 记忆、记忆内容、添加/编辑记忆 | 原浅色背景，busy/保存/清空/错误重试与PopScope不变 |
| 设置→Skill卡片 | Skill卡片 | 原浅色背景、排序与底部恢复默认不变 |
| 设置→模型 | 语音模型与音色、下级克隆认证/候选/结果完整流程 | 原页面背景、返回/重置身份状态不变；模型/音色/创建选择Sheet不变 |
| 设置→邀请 | 邀请活动、邀请详情、邀请记录 | 原背景，蓝底邀请详情保留白色前景 |
| 设置→其他 | 实时翻译原音、关于PhoneAgent、账号管理、开发者功能、固定外呼号码、主叫所在国家、账号翻译模型（调试） | 原路由、背景、禁用和旧回调防护不变；外呼未解锁状态头部也接入 |
| 会员与积分 | 会员与积分、购买积分/积分、订单与发票、购买结果 | 原白色导航背景，原右侧订单与发票操作不变；原订单不匹配查询头部也接入 |
| 积分 | 积分钱包、积分流水 | 原页面背景、刷新与流水入口不变 |

设置主页面不改；Dialog/Sheet/PopupMenu、原生SDK及系统页面不改。可信来电介绍页本无导航栏，不新增。独立研发演练入口不全局替换；共享正式页面被演练复用时自然使用相同头部。

## 自动验证

- Flutter 3.32.0 / Dart 3.8.0；未升级依赖或工具链。
- `flutter analyze --no-pub`：无问题（最终代码复核见正常工具输出）。
- 新导航栏14项：双平台主题、320/390/430宽、1/2倍字体，长标题实际截断、中心点与操作不重叠、动态多操作、无/禁用返回、44点击区、64高度、原主题背景与单次安全区；最终与记忆保存、积分布局、设置外呼、邀请入口、订单空态组合39项通过。
- 最后补充AppBar明确showBack=true但onBack=null保持禁用；核心14项加订单空态/商业页共20项通过。
- 模块集合：settings、memory、commerce、points、invite、call_models、voice_clone；另含home卡片、旧header兼容、shell设置返回和账号入口。2228通过/15失败，没有声称全量通过。
- OpenSpec本change strict通过，UTF-8与git diff --check通过。

## 基线失败核对

从初始HEAD c42719f6以git archive导出lib/test/tool/pubspec到独立临时目录，依赖使用原锁定缓存，package_config的项目路径指向快照；未临时还原主工作区。失败7文件在快照15通过/15失败；失败名称逐项比较与当前集合完全一致。

| 文件 | 既有失败数 | 类型 |
| --- | --- | --- |
| settings/voice_transport_preview_test.dart | 3 | ready前PCM预期断言 |
| call_models/call_model_quality_shell_test.dart | 1 | iOS支付恢复残留计时器 |
| call_models/clone_entry_action_semantics_test.dart | 4 | 同上 |
| call_models/clone_entry_price_shell_test.dart | 1 | 同上 |
| call_models/voice_close_semantics_test.dart | 1 | 同上 |
| voice_clone/clone_entitlement_route_test.dart | 3 | 同上 |
| shell_settings_platform_back_test.dart | 2 | 同上 |

最初快照工具运行因/var与/private/var别名及缺tool源码失败，修正快照后才得到以上基线证据。没有为变绿删除业务断言或修改支付/音频流程。

## 未验证

未打包安装、未在Android/iOS真机截图验收，自动双平台主题测试不等于真机外观验收。未执行真实服务、支付、开票、认证或外呼。不提交推送、不切分支、不归档。
