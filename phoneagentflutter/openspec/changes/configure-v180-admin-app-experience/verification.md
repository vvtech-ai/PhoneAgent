# Flutter 实施与验证记录

## 独立验收与代码交付

2026-10-26：独立只读验证者复核生产投影、调用方、DTO、完整差异和混合字号图片，独立执行 membership_display_items_test.dart、call_model_presentation_order_test.dart 共8项通过，结论 APPROVE（代码阶段）。本次widget图片不冒充Android/iOS真机；代码交付身份以包含本记录的提交为准。

## 源码与范围

- 检出：`feature/test_v1.8.0`，基线 `c42719f62f713a07db61447cf13c53df1d58de96`，本批为未提交改动。
- `membership_benefit_items.dart`：独立只读展示投影，生成真实月积分首行，消费手填列表，保持旧配置回退。列表投影函数的长度来自月积分、手填项与旧兼容分流；同属展示投影，无网络、存储、权限或 UI 渲染职责，不机械拆成更多文件。
- `membership_benefit_row.dart`：独立行渲染，常规标题/描述 13/11，放大 18/13；长文自然换行，月积分数字沿用蓝色强调。
- `membership_benefit_list.dart`：仅组装有稳定 id 的行，不再承担文案生成或样式细节。
- `CommerceDto.catalog/membership` 原样保留 benefits Map，无需修改解码；`MembershipOffer` 为唯一列表调用方，商品预览和当前权益分别传入各自原 Map，客户端不覆盖购买数值。
- 通话目录无生产代码改动；现有 SDK 顺序、账号/任务选中已符合合同，只新增回归。
- 未改既有两个打包脚本、安装版本、平台配置、权限、扣费、支付或任务状态机。

## 红绿回放

新增 `membership_display_items_test.dart` 后，旧实现出现 3 个预期失败：手填标题缺失、空数组仍显示旧声音克隆介绍、长文手填项缺失。旧配置回退测试已通过，确认失败为新增行为缺失。日志：`.dart_tool/v180-membership-red.log`。

完成实现后，新权益测试及既有 `membership_presentation_test.dart` 共 12 项通过。随后增加 DTO 保留发布介绍/购买月积分、目录顺序与任务选中回归，共 10 项通过（含 Android/iOS 平台配置下的恢复任务连续选模）。这些为 Flutter 测试平台，不是真机。

## 自动验证

固定 Flutter 3.32.0 / Dart 3.8.0，JDK `D:/tools/phoneagent-jdk17/jdk-17.0.20.1+1`，不升级依赖。

定向回归命令：

```text
flutter test --no-pub --reporter expanded
  test/features/commerce/membership_display_items_test.dart
  test/features/commerce/membership_presentation_test.dart
  test/features/commerce/membership_page_test.dart
  test/features/commerce/membership_copy_layout_test.dart
  test/features/commerce/membership_config_layout_test.dart
  test/features/commerce/membership_model_benefit_test.dart
  test/features/commerce/membership_partial_page_test.dart
  test/features/commerce/membership_latest_ui_test.dart
  test/features/commerce/membership_purchase_snapshot_test.dart
  test/features/call_models/call_model_presentation_order_test.dart
  test/features/call_models/call_model_api_test.dart
  test/features/call_models/conversation_model_sheet_test.dart
  test/features/call_models/apology_task_model_sheet_test.dart
  test/features/call_models/model_membership_hint_widget_test.dart
```

结果：59 项通过，日志 `.dart_tool/v180-flutter-regression.log`。既有会话测试刻意构造的 commerce 读取失败日志为测试夹具，不是本批真实联调结论。

- `flutter analyze --no-pub`：通过，`No issues found!`，85.8 秒，日志 `.dart_tool/v180-flutter-analyze.log`。
- `openspec validate configure-v180-admin-app-experience`：通过。
- `git diff --check`：通过；Git 提示本地 LF 在后续 Git 操作中按仓库设置转 CRLF，不是空白错误。
- 本批源码/测试用严格 UTF-8 读取并检查 U+FFFD：通过；中文标题、说明与测试断言已读回。

## Flutter 视觉证据

使用实际 `MembershipPage`、`MembershipOffer`、`MembershipBenefitList`，合成发布配置，在 Flutter widget 测试引擎中渲染。加载本机微软雅黑和 Flutter Material Icons，`RepaintBoundary.toImage` 输出 PNG。不是网页截图，不是真机截图，不代表真实后端发布已生效。

命令：

```text
flutter test --no-pub --reporter expanded
  --dart-define=COMMERCE_CAPTURE_DIR=build/v180-membership-ui
  --dart-define=UI_PREFLIGHT_FONT=C:/Windows/Fonts/msyh.ttc
  --dart-define=UI_PREFLIGHT_ICON_FONT=D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
  test/features/commerce/membership_display_visual_test.dart
```

3 项通过，已查看图像：

| 场景 | 预期与结果 | 证据 |
| --- | --- | --- |
| 常规字号，390×844 | 每月 4500/赠送600 只读，介绍全部常规，沿用现有会员卡布局，无溢出 | [常规](../../../build/v180-membership-ui/membership-regular.png) |
| 混合字号，390×844 | 月积分和新模型介绍放大，声音/批量介绍常规，字体对应、顺序与分隔清晰 | [混合](../../../build/v180-membership-ui/membership-mixed.png) |
| 长文，320×568，字体2倍 | 文案自然换行、列表可滚动、无布局异常，当前截图是滚动后权益区域 | [窄屏](../../../build/v180-membership-ui/membership-narrow-large.png) |

## 未验证与边界

- 独立验证：原实现与远端导航栏集成后均经独立只读审查批准，详见本记录独立验收与合并段落。
- 未在 Android/iOS 真机安装或执行；未打 APK/IPA。
- 未启动或写入真实后端，未运营发布，未真实外呼/支付。
- 后端与 Web 契约在本 change design 中固定；后端实现者已确认有效权益使用 published.displayItems，同时保持 purchased 的月积分数值。

## 推送前远端导航栏集成复验

2026-10-26 推送前 fetch 发现远端 `feature/test_v1.8.0` 增加统一详情导航栏提交 `921647c04140c7fb41873508e995df615983da43`。root 在本轮实现提交 `f287266f3db1807ab6fbdbdd0cc5d51ca6e3c544` 上执行无提交合并，自动合并无冲突。本次在该合并工作树（`HEAD=f287266f`、`MERGE_HEAD=921647c0`）复验，不修改远端导航行为。

- 重跑上述 14 文件定向回归，并追加 `test/core/native_page_header_test.dart`：73 项全部通过，日志 `.dart_tool/v180-merge-regression.log`。
- 用上方同一截图命令重跑 `membership_display_visual_test.dart`：3 项全部通过，日志 `.dart_tool/v180-merge-visual.log`。本页三张图片已更新为最终导航栏渲染；390px 标题居中，320px 双倍字体保留远端导航栏的标题省略规则，权益长文自然换行且可滚动。
- 全仓 `flutter analyze --no-pub`：通过，`No issues found!`，30.3 秒，日志 `.dart_tool/v180-merge-analyze.log`。
- 本次集成复验无业务源码或测试断言修改；既有两个打包脚本仍各 3 行新增/3 行删除，保持用户修改。
- 这些仍为实际 Flutter widget 测试引擎与合成配置证据，未在实体设备安装或运行；真实后端发布、Android/iOS 真机验证仍未执行。

独立补审：验证者复核合并后的 sheet/会员调用、最终混合字号图及差异，未发现合并遗漏；合并后73项回归、3项视觉与analyze结果经核对，批准代码阶段交付。

## 2026-10-26 用户反馈续修：统一翻译默认及原色

开发基线fetch/快进24951575，保留两个既有用户脚本各3增3删（备份/重放后仍未提交）。当前统一翻译排序，不分国内外；颜色以最后纠正“是积分蓝色不是所有标题蓝色”为准。

- TranslationDirectory/API解码增加nullable defaultTranslationModelId，缺失/null/空串兼容旧服务。纯选择策略有效exact ID→国家绑定与协议允许的统一默认→当前序首可用；未下发默认沿旧engine兼容。已打开任务、目录排序与质量探测不改，保留原地区/语言归一化/准入。
- 会员月积分原先仅数字高亮逻辑保留，周围标题#202532、数字#3478F5；常规说明恢复原#858991，大说明#7D8491，配套13/11和18/13。没有改写任何实际权益标题，长84字/200字由发布配置完整呈现。
- 新10项选择策略曾7项预期失败后全过；国内/国际真实弹窗入口2项覆盖默认、显式选择、顺序不因选中/延迟改变。定向10文件48项通过；flutter analyze No issues found（243.1秒）。
- 用户颜色纠正后先复现整行蓝断言失败，再恢复仅数字蓝；最终membership_display_items_test6+membership_display_visual_test4全过。视觉使用实际MembershipPage/Offer/List Flutter组件引擎、合成发布配置及本机字体，build/v180-benefit-followup/membership-{regular,mixed,narrow-large,long-models}.png；390常规/混合、320双倍字体及84字模型标题自然换行。不是网页，也不是真机。
- 独立测试者最终6文件34项通过，含最终颜色、翻译策略和国内/国际入口、目录兼容与首页/任务模型排序；直接查看最终Flutter长模型图，数值蓝/原深色和原标题匹配最新要求。
- 扩大翻译族及相关会员/偏好：962通过、27失败、1跳过。失败分布：跨境入口4、国内质量3、国内弹窗6、原模型面板8、translation_access_pages2、诊断ZIP1、translation_pages3。仅代表性国内旧semantics与质量ApiFailure共2项已将本次3个翻译生产文件还原HEAD对照，仍失败；finally恢复全部本次源码。其余25项未逐项证明基线，不能宣称全量通过。Windows符号链接权限造成1跳过。未扩大修复无关功能。
- 未打包/安装、未运行真实后端或Android/iOS真机、未真实外呼/支付。OpenSpec、diff及UTF8中文检查通过。
推送前并发远端集成：本轮8fb2f94e提交后远端新增a4654b16（问题反馈控件配色），已无冲突合并保留4个远端文件。root合并工作树重跑membership_display_items、translation_model_presentation、translation_model_presentation_entry、support_feedback/feedback_page共28项全过；独立补审确认本轮会员/翻译源码对象未改、原两个用户脚本仍各3增3删未暂存。没有打包/部署。