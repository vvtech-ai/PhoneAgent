> 历史排查记录：2026-10-29用户已确认头像恢复显示，并要求移除本次专用调试日志；下文为此前诊断阶段记录，当前实现以fix-live-activity-avatar-size-fallback为准。

# Live Activity头像压缩日志验证

## 修改边界
仅头像诊断：默认屏幕倍率、40×40点、JPEG0.6/0.35/0.15、1536字节单图、32KB输入与4096字节整体限制、编码尝试与Activity请求顺序均保留；不改NSE/下载/认证/音频/crash处理器和UI。不切当前test_v1.8.0_fix，不提交推送。

## 如何读日志
原日志上传中查trustedCaller.code=IOS_ACTIVITY_AVATAR、trustedCaller.avatar。eventId对应来电，attemptId区分本次创建或重试，appVersion/appBuild读取主包Info，osVersion来自实际系统。

| phase | 证据 |
|---|---|
| input | inputBytes/inputLimit/imageLimit，input_empty或input_ready |
| render | inputWidth/inputHeight、renderScaleMilli、pixelWidth/pixelHeight；3000表示scale3 |
| attempt | quality为0.6/0.35/0.15，jpegBytes为实际生成字节；encoded/over_limit/encode_failed |
| selection | selected与所选quality；或input_limit/input_empty/decode_failed/all_failed |
| budget | encodedBytes（现有属性+状态各JSON编码长度之和），fits或removed_over_budget；afterRemovalBytes记录移除后的长度；编码失败独立reason |
| request | with_avatar/without_avatar记录请求入口，created/request_failed记录返回结果；hasAvatar是最终携图布尔 |

例如input有图、三档全over_limit、selection=all_failed：压缩丢弃；selection=selected但budget=removed_over_budget：整体超限丢弃；request=with_avatar且created：客户端已携图创建，但不能据此宣称系统实际渲染成功。事件缺失不能推断阶段未发生，进程终止/Flutter消费者未接上/缓冲覆盖/日志过滤仍有边界。沿既有INFO/DEBUG日志策略；WARN/ERROR会过滤普通info事件，未改变全局等级。没有读取图片、URL、姓名、号码或原始异常。

## 自动验证
- 新回归先红：原通道吞掉IOS_ACTIVITY_AVATAR；实现后通过。
- native Foundation测试通过：封闭枚举/数值/版本/UUID、敏感字段过滤、64条缓冲与旧consumer隔离、原APNs错误白名单回归。
- tool/test_live_activity_avatar_diagnostics.py通过：抽取生产Swift函数与budget分支，验证三档实际顺序、首成功返回、全部失败、空输入/超限/解码与编码失败、3倍渲染指标、整体超限回退及无图仍超限。UIKit/ActivityKit由替身代替，仅用于分支/日志与原算法回归，不能证明设备实际编码或显示。
- 相关Flutter日志与诊断134项通过；扩大278通过1失败（未改支付模块IosPaymentRuntime.boundRecovery的15秒timer导致iOS设置页测试退出遗留，单独复验仍失败）。没有修改/删除该断言，不声称扩大全绿。
- 最后头像日志→journal实际写入→重读、归档直接调用方23项通过；与134项有重叠，不累计。未运行全量。
- flutter analyze通过，无问题。Mac iOS Debug无签名编译16.2秒通过；未导出签名IPA/安装，不作为真实设备验收。
- 首次iOS编译发现renderer.format静态基类无scale，安全转换具体类型后复编通过；无force cast，不改变实际renderer默认配置。Swift替身首次缺CoreGraphics导入已核对补齐并复验。
- 构建自动刷新旧Pod锁与工程空列表；仅在确认与本次生成哈希一致后恢复两文件，临时patch保留于/tmp/phoneagent-avatar-build-generated.patch。未改工具链或签名配置，固定崩溃Pod沿既有Podfile解析。

## 二进制与符号
主程序UUID EE7AB58A-CEB0-3C7F-BC7B-C93D89CF58DE；Runner.debug.dylib UUID 4C8608C7-22E5-3852-B7AA-2C223D4B283F，均与dSYM匹配。
保留副本：/Users/Eason/.cache/phoneagent-avatar-diagnostics/20261029_112736

## 待验
任务5：新日志构建的真实设备推送（正常/异常设备）、后台/锁屏、实际渲染、账号切换和上传完整性。仅枚举设备，没有安装、发推送、认证、外呼或上传。需要现场日志后才能确定丢头像原因和所选质量，不把代码/测试当作已定位根因。

最终文档校验：OpenSpec273项通过、diff检查通过；末轮analyze无问题。未提交、推送或安装；任务5仍待真机同构建验证。
