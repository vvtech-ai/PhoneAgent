# 会员支付居中确认弹窗

用户明确视觉：居中白圆角、约342宽、内容左右24、标题左、灰标签深值、蓝金额、浅蓝渠道卡、左方checkbox及横排取消/确认并支付。参考只读旧仓 origin/codex/phone-agent-monetization-linkage-20260814 的demo样式，用户当前图优先；不复制旧差价/折算/补发规则。

## 文件职责

生产：
- lib/features/commerce/presentation/widgets/membership_confirmation_sheet.dart：Dialog容器与选择/协议/提交状态，保留原调用接口。
- lib/features/commerce/presentation/widgets/membership_confirmation_details.dart：可信报价明细；目标等级/周期、全价、首期、暂停及排队说明，窄屏金额自适应上下布局且字符串不拆行。
- lib/features/commerce/presentation/widgets/membership_confirmation_payment.dart：现有平台渠道卡、方协议框与横排动作。
- lib/features/commerce/presentation/pages/membership_route.dart：会员入口showDialog，builder上下文只关闭Dialog；积分与结果入口保持原流程。

测试：新增membership_confirmation_dialog_test.dart、membership_confirmation_route_test.dart、membership_confirmation_visual_test.dart；更新membership_confirmation_v2_test.dart、membership_route_v2_test.dart、direct_checkout_route_test.dart的现有文案与真实交互断言。

规范：openspec/changes/polish-membership-confirmation-dialog下proposal/design/tasks/delta spec；根tasks.md及docs/codex_issue_log.md。

当前平台唯一有效渠道默认选中，不新增虚构渠道。协议仍初始false，禁用渠道不能选或提交。重建不覆盖已有状态。同步提交守卫验证同帧旧回调只提交一次；iOS金额直接使用StoreKit当地格式，Android金额使用可信报价，不修改后端契约。

## Fresh验证

Flutter3.32.0，Dart3.8.0。先RED复现缺少Dialog，随后实现、调用方兼容、可视化审查和定向回归。

最终56 passed / 0 failed，包含原有checkout/controller、iOS当地金额与变价、四种会员真实route、取消/遮罩/back无创建、禁用渠道、协议主动确认、同帧防重、架构。日志.superpowers/evidence/membership-confirmation-dialog-final.log，无Warning/missed-tap。analyze最终No issues found，17.1秒；本change strict通过，git diff --check通过。

```text
flutter test --no-pub --dart-define=COMMERCE_CAPTURE_DIR=build/test-results/membership-confirmation-dialog --dart-define=UI_PREFLIGHT_FONT=C:/Windows/Fonts/msyh.ttc --dart-define=UI_PREFLIGHT_ICON_FONT=D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf test/features/commerce/membership_confirmation_visual_test.dart test/features/commerce/membership_confirmation_dialog_test.dart test/features/commerce/membership_confirmation_route_test.dart test/features/commerce/membership_confirmation_v2_test.dart test/features/commerce/membership_route_v2_test.dart test/features/commerce/direct_checkout_route_test.dart test/features/commerce/membership_checkout_test.dart test/features/commerce/ios_checkout_price_test.dart test/architecture_test.dart
flutter analyze --no-pub
openspec validate polish-membership-confirmation-dialog --strict
git diff --check
```

可视化审查曾发现320宽/2倍字的金额折行，已修为按实际字宽上下布局、原金额完整单行，增加行数与几何断言。20个前置套餐真实showDialog可滚动，取消/确认按钮可达；不通过关闭tap警告规避失败。

## 截图

完整中文字体，均由真实showDialog产生，位于build/test-results/membership-confirmation-dialog：
- confirmation-new.png、confirmation-upgrade.png、confirmation-renew.png、confirmation-lower_queued.png：390宽初始未同意协议。
- confirmation-upgrade-ready.png：用户勾选协议后的蓝色确认按钮，已目测。
- confirmation-small.png：320×568、2倍字体、20前置套餐；金额单行已目测，滚动可达动作由测试验证。

账号owner/current、会员开关和原生价格保护沿用已有checkout，并在直接调用方测试覆盖；取消/遮罩/系统返回仅关闭Dialog，底层会员页仍存在。未进行真实支付、构建、安装、提交推送或后端更改。测试和analyze命令均已结束；机器既有4个flutter_tester为10/8、10/10创建的残留，不属于本轮，未擅自清理。
