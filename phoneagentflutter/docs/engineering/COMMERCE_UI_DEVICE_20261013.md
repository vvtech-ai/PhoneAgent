# 1837 UI最终Android设备复验

只读页面复验与已授权同签名升级。1301是中间包，最终包为1302。本agent不运行Flutter/analyze/Maven，不修改业务源码、共享tasks或issue；构建和定向验证由主线程执行。

## 产物与安装

- 包名`com.vvtech.aiassistant.dev`，versionName`1.0.51`，versionCode`2026101302`（高于原1208与中间1301）。
- APK位置`build/app/outputs/flutter-apk/app-debug.apk`，SHA256 `ED626D32D490022848CC1070617B27C92A8776E1F2BF577FEF08EBADAE7E37AB`。
- apksigner证书SHA256 `45655392a9295955d0d651eb7d1ff3f3edb1d15f8a62d74f201dfbc3789cdb4b`，与已装1208证书一致。
- 实体机`AEUN9X1507G02040`，KOZ_AL00；另一模拟器未操作。
- 命令`adb -s AEUN9X1507G02040 install --no-incremental -r build/app/outputs/flutter-apk/app-debug.apk`返回Success后才启动MainActivity；沿现有授权完成OEM单次允许，不修改安全设置。
- firstInstallTime仍`2026-10-10 12:36:18`；lastUpdateTime为`2026-10-13 01:32:03`。未卸载、清数据、降级，首页登录与余额8989保留。
- 原1208安装包只读保存在忽略路径`output/commerce1837/installed-before-1301.apk`，SHA256 `9C07F6E243189F4EC571D7D9E96F0007072EE0E43A3385344A059A0F52EE9E02`。不主动降级。

## 实际页面与HTTP

真实720×1600截图在忽略目录`output/commerce1837/`，均已逐张查看：

| 截图 | 实际结果 |
| --- | --- |
| android-1302-home.png、home-return.png | 普通首页、礼物入口、登录余额保留；最后停留此页 |
| android-1302-settings.png、invite.png、welfare.png | 设置邀请好友及首页礼物分别进入邀请好友/福利，两个未邀请槽可用、蓝按钮正常；未点击实际邀请 |
| android-1302-invite-records.png | 真实0/2空态与表头、来源返回正常；真实非空记录仍未产生 |
| android-1302-membership.png | 紧凑总积分卡，可用8989与预占0、购买积分及流水直达，无会员/永久分项或来源入口 |
| android-1302-ledger.png | 原纯积分列表、收支颜色、时间、说明与操作后余额；返回会员，再可返回首页 |
| android-1302-points.png | 实际服务不可用与重试，确认支付禁用，无假商品或成功数据 |
| android-1302-orders.png | 实际订单服务不可用与重试，无假空订单成功或发票状态 |

新进程15370的安全元数据文件`android-1302-protocol-metadata.log`只保存允许的路径/status/字段形状与名额，不包含token、邀请码值、query值或原始响应。

| 实际SDK路径（统一前缀/aiassistant-sdk-api） | HTTP/apiCode |
| --- | --- |
| /api/invite/activity | 200/000000 |
| /api/invite/me/code | 200/000000 |
| /api/invite/me/records | 200/000000 |
| /api/commerce/catalog | 404/OTHER |
| /api/membership/current | 404/OTHER |
| /api/commerce/orders | 404/OTHER |

邀请码形状String长度4、HTTPS发布host与入站白名单不匹配但可信API结构校验正常、唯一code参数匹配、有效期可解析且未来、used0/reserved0/available2。未输出值，不放宽外部入站白名单。三个失败页面重试后仍是404错误，未变为空数据成功；发票、购买与后台部署不能称成功。

## 大字和限制

修后`ui-recheck/v67-reward-375-2x.png`合成图独立检查无金额/说明重叠，默认构图保留。奖励、非空邀请记录和专票键盘图都是合成证据，不是真实资金或实际系统键盘验收。该设备未改变系统字号；2×证明来自绘图及矩形回归。

1302冷启动第一次uiautomator短暂null root node；重新读取MainActivity与页面后重试一次正常。本地安全日志AppendAllLines重载不匹配，确认原文件未改变后改AppendAllText UTF-8，读取确认六路径完整。无业务操作重放。未进行真实分享、短信、外呼、支付、克隆或奖励确认；iOS本轮Mac不可达仍未编译。
