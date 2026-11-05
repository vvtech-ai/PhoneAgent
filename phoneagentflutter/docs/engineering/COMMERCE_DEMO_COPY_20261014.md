# 会员积分及订单 UI 再对齐

## 依据与范围

按用户 2026-10-14 三项要求，以旧项目 `origin/codex/phone-agent-monetization-linkage-20260814`（`7e7bd38`）的 `monetization-demo/js/monetization.js` 第 86、88、97、111 行为展示参照。旧项目只读。本轮基线 `6d1dc1bc`，fetch 后与 `origin/codex/story1837-membership-commerce` 一致；保留原有 `account_protocol_diagnostics.dart` 工作区标记，不纳入提交。

## 实际修改

| 位置 | 本轮结果 |
| --- | --- |
| 积分余额下方 | 恢复“约可通话 xx 分钟 · 今日赠送 xx 积分已到账”；从现有钱包与费率接口读取，未知费率不假定 100，未到账或过期钱包不显示已到账。移除此处预占文案，保留积分流水入口。 |
| 订单与发票 | 非空时恢复“左右滑动查看支付渠道与状态”，空态不显示说明或箭头；表头改“状态”，完成订单在列表显示“已支付”；金额加粗。 |
| 订单类型与渠道 | 保留原单等级和周期投影“初级会员·包月/包季/包年”，ALIPAY 显示支付宝；历史 WECHAT 可显示微信支付，未知渠道显示横杠。没有增加微信购买入口。 |
| 联系方式 | 统一小号居中“会员反馈联系：邮箱”，读取发布目录 supportEmail；会员页去除重复泛化售后按钮，积分购买与历史支付页改为邮箱。支付反馈弹层仍只有完成。 |
| 积分购买按钮 | 实际渠道 ALIPAY 显示“支付宝购买”，其余渠道保留确认支付。 |
| 周期价格卡 | 保留已实现的等高、独立原价/折扣；月度也支持真实配置折扣，不回退 Demo 季度起折扣限制。 |

新增独立 `CommerceSupportContact` 仅处理邮箱展示，页面不发请求。余额路由仅组合已有 provider，复用积分估算规则。支付、开票、金额、权益、声音克隆、服务端和数据库没有业务修改。

## 复核及边界

- Demo 自动续费与当前单次购买不同，继续显示真实“单次购买，不自动续费”，订单类型不添加“连续”。
- 已配置模型与声音克隆说明保留真实能力，不把 Demo 宣传或免付费假设当作服务能力。
- 发票详情尚缺票号、开票日期等完整公共契约，列表没有可可靠区分“开票中/已开票”的字段；保持当前真实查看入口，没有把申请号冒充税票号或虚构重发。本轮未恢复税航联调。
- 旧 `output/commerce1837/ui-recheck` 图不是当前 UI 证据。本轮重新绘制，合成截图不是手机截图或真实支付证明。

## 验证

```powershell
D:/tools/flutter-3.32.0/bin/flutter.bat analyze --no-pub
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce
openspec validate align-commerce-demo-copy --strict
openspec validate --all
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/commerce_visual_test.dart --dart-define=COMMERCE_CAPTURE_DIR=D:/Temp/story1837-ui-20261014 --dart-define=UI_PREFLIGHT_FONT=C:/Windows/Fonts/msyh.ttc --dart-define=UI_PREFLIGHT_ICON_FONT=D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
```

- `analyze` 无问题（14.3 秒）；商业化模块 278 项全部通过（38 秒）；OpenSpec 本 change 严格通过，全部 104 项通过。
- 375/390/430、1×/2×共 48 个页面渲染用例通过；主代理已查看会员/积分/订单 390×1 和会员 375×2，其他关键图由独立 agent 复核。首次余额卡增加说明导致旧紧凑高度测试 153>145 失败，改为余额右侧流水入口后通过；真实数据提示测试新增前缺参数编译失败，实施后通过。订单专项先 4 通过/6 失败，修复后与原单操作集合 17/17 通过。
- 邮箱回归包含非 Demo 配置邮箱、空邮箱不伪造、按钮位置、历史已支付/未支付；普通直购/升级与支付前后隐藏订单技术信息回归保持通过。
- PMReport 按插件 registry 检查：实际修改仓库 phoneagentflutter 未登记，旧 aiassistant 仅参考，不在本轮发送进度。

## 交付

Android debug APK 构建通过（76 秒），版本 `1.0.51 / 2026101401`，包名 `com.vvtech.aiassistant.dev`，已用 aapt 读回核实。

- 包路径：`D:/Temp/story1837-local-device/phoneagent-commerce-ui-1401.apk`
- SHA256：`5516861839f9782f500dc7596860e36378a85a9bea3fe1246096197d42056919`
- 沿用先前私有本地开发配置，SDK 为 USB 转发的 `http://127.0.0.1:18082`；使用 `--dart-define=ENABLE_INVITE_PROTOCOL_DIAGNOSTICS=false --dart-define=ENABLE_MIGRATION_PREVIEWS=false`。
- 上轮设备安装被系统拒绝，本轮未重试安装、清数据或发起支付；不能宣称手机已生效。iOS 真机视觉仍待设备验证。
- 独立复核未发现阻断；375×2 订单提示末字单独换行属轻微排版差异，完整可读。发票详情契约差异见上节，未宣称全部 Demo 功能一比一移植。

源码提交 `d9264b1a` 已推送 `origin/codex/story1837-membership-commerce`，推送后 ahead/behind 为 0/0；仅原有诊断文件工作区标记保留。
