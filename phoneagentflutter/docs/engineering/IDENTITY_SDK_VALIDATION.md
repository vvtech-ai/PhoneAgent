# 身份采集 SDK 双端适配与验证

## 最新接续（2026-09-18）

正式克隆创建流程已在后续批装配真实SDK，本轮再接入共享音频保护；下方“没有接通正式创建入口/未来装配”为最初SDK批次历史，不代表当前实现。`FocusedIdentityCapturePort`在采集前申请不可被试听抢占的租约，退出/换账号作废旧结果。`waitForRelease(session)`作为第四个通道方法等待原生完成，abort返回本身不证明释放。Android release失败保留句柄并允许abort重试，iOS等待供应商回调及自身容器关闭，未使用私有取消接口。

iOS若永不回调，**现在同一focus下其他播放也会保持被阻止**，不是只阻止再次采集；普通非媒体页面不依赖该锁。不能以超时强制释放后允许多个媒体并行。真实设备指示器/供应商取消行为仍待集中验证；完整实现、自动证据与新增人工步骤见[AUDIO_FOCUS_VALIDATION.md](AUDIO_FOCUS_VALIDATION.md)。本轮18新增/1775全量、三端构建及隔离Web演练通过，无真实SDK、身份、权限操作或设备安装。

更新：2026-09-18。本批完成固定 SDK 的原生薄适配、共享通道契约和构建资源验证；**没有进行真实 SDK 认证，也没有接通正式创建入口**。共享页面仍用明确标识的 MOCK 演练，完整装配属于 home-model-shell 5.10。

## 来源和集成边界

- Android：固定 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 8 个认证 AAR，位于 `android/app/libs/identity`。依赖沿用 v65 的 OkHttp 4.12.0 / fastjson 2.0.31；不含可信来电 SDK。
- iOS：固定 `ddb996a28f98559ea7d8b76ca9d7712703dedbc1` 的 AliyunIDPro_iOS_2.3.50，14 个 framework、8 组 bundle，共 328 文件，位于 `ios/IdentityCaptureSDK/Vendor`。保留供应商版权与许可，不宣称开源授权。
- `scripts/verify-identity-sdk.ps1 -SourceRepository <旧仓库路径> -Apk <APK路径>` 对全部 336 文件逐一校验 Git blob；APK 内 arm64-v8a / armeabi-v7a 共 12 个原生库和 4 项 assets 逐字节等同 AAR。未覆盖任意 x86 模拟器兼容性。
- `.gitattributes` 禁止 SDK 目录文本换行转换。首次导出发现 Windows core.autocrlf 改变部分 strings/header，已用 `git -c core.autocrlf=false archive` 重新提取并通过全部校验，不修改供应商正文。

Android 首次构建的加固 ELF 裁剪警告通过指定 6 类供应商 so 的 keepDebugSymbols 处理；最终 APK 字节校验通过，不对加固二进制执行修改。iOS 用静态本地 Pod，使资源落在主 App 根目录，SDK 与自有插件符号静态链接进 Runner；不依赖旧动态包装框架中的资源。

集成依据：[阿里云 Android 意愿认证接入](https://help.aliyun.com/zh/id-verification/financial-grade-id-verification/integration-by-using-android-intent-verification)、[iOS 意愿认证接入](https://help.aliyun.com/zh/id-verification/financial-grade-id-verification/integration-by-using-ios-intent-verification)。版本仍以固定源为准，不下载或升级新版 SDK。

## 共享与原生职责

| 层 | 文件 | 负责 | 不负责 |
|---|---|---|---|
| Flutter data | `device_identity_capture_port.dart` | 独立 session、prepare 单飞/缓存、一次 capture、abort 幂等、晚到与异常脱敏 | 不伪造 metaInfo、不调用业务 HTTP、不将 SDK 成功判 PASS |
| Android | `IdentityCaptureChannel.kt` | 后台 install/getMetaInfos、主线程采集、全局占用、release、设备网络摘要 | 不发送候选或认证完成接口、不访问账号数据库 |
| iOS | `IdentityCapturePlugin.h/.m` | initSDK/meta JSON、专属展示容器、主线程占用与回调、关闭本次容器 | 不使用供应商私有取消 API、不以 reachability 冒作已验证网络 |
| 共享认证控制器 | `clone_verification_controller.dart` | init/status/observation、后台 PASS 判定、有界核验 | 不控制原生页面、不直接保存/生成克隆 |

通道名 `phone_agent/identity_capture`，三个方法均带 session。构造或插件注册不主动调用 SDK；只有未来共享页面完成显式授权后才能 prepare。capture 接后台 certifyId；返回只保留 code、符合白名单格式的诊断 subCode、设备型号及网络枚举，不跨通道暴露 SDK 原始 reason、图像或 deviceToken。Web/桌面明确拒绝真实采集，不自动回退 MOCK。

Android CAMERA 为可选硬件；保留 RECORD_AUDIO、增加 ACCESS_NETWORK_STATE，移除 AAR 带入的旧外部存储权限。最终 manifest 仍包含供应商自身的 ACCESS_WIFI_STATE、FOREGROUND_SERVICE、非导出 EvidenceService 和风控包可见性声明；不等同于 App 主动执行录屏，需纳入最终 SDK 隐私披露审核。本批未启用额外录像、相册、定位或 NFC 认证流程。iOS 相机/麦克风用途说明已打入测试 Bundle ID。

## 关闭与重入限制

Android abort 只释放自身 session；prepare 尚在后台执行时保留全局占用，完成后才能接新请求，避免两个 SDK 安装/采集重叠。SDK 回调和 close 后返回均做身份检查。

iOS 固定公开头文件没有可靠 abort/release 方法：取消时关闭本次容器、返回 cancelled、清除敏感缓存并丢弃旧结果；**旧 SDK 尚未回调时保持 busy**，不能声称相机已经强制释放。若供应商永不回调，后续采集会保持不可重入，需在真机验证并与供应商确认公开取消方案；不能通过超时清锁让两个采集并行。App 正常其他页面不依赖该锁。

## 自动验证证据

- 12 项新增通道测试：Android/iOS 延迟准备与缓存、Web/桌面拒绝、独立租约、未准备/非法参数、一次性采集、prepare/capture 取消晚到、无效响应、异常脱敏和缺失插件。
- 全量 1116 项通过；flutter analyze 无问题；524 文件格式检查；19 项 OpenSpec 通过。
- Web Debug 同源代理构建、Android Debug 测试环境构建通过；上述 APK 原生库/assets 与全部供应商源文件校验通过。
- Mac Xcode 15.2 / Flutter 3.32.0 / iOS 15.5 最低版本无签名 Debug 构建通过；最终 8 组认证 bundle 位于 Runner.app 根目录，nm 确认 AliyunFaceAuthFacade / IdentityCapturePlugin 链入 Runner，Bundle ID 为 com.chaken.phoneagent.test。
- CocoaPods 仍提示既有 Profile xcconfig 警告；本批只验证 Debug，不据此声称 Profile/Release 已验收。Flutter 初次未自动识别本地 podspec 的静态变化，显式 pod install 后重建并核实产物。
- 没有新设备安装、真实 prepare/metaInfo 采集、身份/录音上传、生成/扣费或后台写入；未改变现有登录或 Mac 已解锁会话。

## 仍需实施和集中人工验收

1. 生产创建页面与真实 SDK/核验/候选/钱包/私有录音装配，替换演练端口但保留独立 MOCK 入口。没有这一步不能声称完整克隆已可用。
2. 核实测试包名/Bundle ID、供应商业务配置与权限。安装和真实认证需明确授权及用户提供合法测试身份；无需为此重发登录短信。
3. 两端分别测试相机/麦克风首次允许、拒绝、撤权、SDK 返回、系统返回、切后台及页面/账号失效。预期只回调一次、不继续旧认证/生成；iOS 重点记录取消后的相机指示器、SDK 回调和再次进入是否 busy。
4. 以时间窗和 attemptId 对齐后台 init/status/observation，SDK 1000/2006 后仍需后台 PASS。FAIL、取消、过期及未知结果不得创建候选；不得记录证号/metaInfo/certifyId/SDK 原文/token。
5. 核验前后台、真机架构、供应商网络与风险失败；自动通道测试不能证明 SDK 权限、相机释放、合法性审核或供应商服务实际可用。视觉差异继续后续集中校准。
