# dev_zys 集成开发包交付

## 来源与边界

用户授权合入最新 dev_zys、构建开发包、保留手机数据安装并提交推送。本次从任务分支 ba80b6b9 合入 06eba014，完成冲突和回归修复后形成 c620a465；交付前 fetch 又发现四个新增提交，继续合入 7a99013c05a7a554f3022b774f9859bd073db2c9。第二次合并只需组合两个历史记录文件。

随后交付核对拉取到可信来电流程修复df5e7097384adcab5161e3faddf1514534928e58，继续三方合入；追加冲突仅根tasks记录，保留双方内容。本次最终来源冻结在该fetch快照；49完成此集成，用户追加正式应用图标后最终包50包含全部代码及图标。

目标始终是 codex/refactor-conversation-task-flow。origin/codex/dev 保持 9a8d4e642ec1e892df4128992b84e8686233e732，不推 dev 或 dev_zys，不修改后端、数据库或旧工作区。

实现合并提交75d44da4已非force推送到上述重构分支；其余c620a465、6377399a也随祖先推送。最终50安装后的任务页面显示QwenOmniPlus ×1.0；静态图标与网络配置复核完成。后续仅同步此交付记录与任务checkbox。

## 集成处理

- 请求层兼容双方错误元数据、签名和账户边界；新增 account_error_mapping 只负责白名单映射，避免 account_api 超过500行。
- 保留任务分支的自动分页、统一对话生命周期、v66确认及完成回执、结构化结果去重；组合 incoming 的可选择转写和可访问语义。
- 翻译入口接 incoming 统一拨号，不增加第二套控制器。任务日期采用 incoming 共享时间规则。录音使用 path.join 保持 Windows 路径一致，保留符号链接和账号隔离校验；显式声明已锁定的 path 1.9.1，仅改变锁文件直接依赖分类，不升级版本。
- iOS 工程保留任务文件通道与 incoming 可信来电插件、资源和扩展，清除合并产生的重复工程对象。
- 更新测试的显式用户协议确认、统一拨号单层返回、原生通知时长和现有控件标识。测试模拟上传器读完流再返回，避免 Windows 测试删除仍打开的文件。正常音色页移除 MOCK 克隆入口，试听按钮沿用最新 incoming 修复。

## 实际验证

固定 Flutter 3.32.0 / Dart 3.8；Android JDK21，过程镜像配置不写入业务接口。

| 验证 | 实际结果 |
| --- | --- |
| 全量 Flutter 回归，修复前快照 | 4290通过、1跳过、53失败；完整执行15分35秒，不能表述全量通过 |
| 失败分组及直接调用方修复后重验 | 60通过、2失败；仅余 Windows 无符号链接特权 errno1314 的录音清理和会话两项 |
| 首页、设置、拨号、任务回执与账号重登连续演练、时间、登录回归 | 最终33通过，46秒；Android/iOS TargetPlatform 与两种尺寸为 widget 演练，不是真实双端外呼 |
| 最新音色试听与生产入口 | 12通过，覆盖双方平台样式和2倍文字 |
| 最新App网络与签名直接调用方 | 34通过，包含模型目录、时延、C1及服务路由 |
| 最终df5e7097可信来电及全部诊断直接调用方 | 255通过，52秒；先期不存在的诊断目录选择器已改为git实际文件集合，不计为成功 |
| Android 原生完整单测 | 60项中58通过、2失败：符号链接权限、Windows renameTo 覆盖现有文件；未降低隐私校验或改变 Android 文件逻辑 |
| Android 可信来电规则定向 | 34通过，无真实SDK认证或来电 |
| 最终df5e7097 Android可信规则 | 36通过，28秒；首次缺少镜像环境导致离线缓存失败，核对后补齐并重验成功 |
| 最终 analyze | 无问题，60.1秒 |
| OpenSpec | 67通过、0失败，不归档未验收变更 |
| 可信SDK来源 | 51文件SHA和10个Android竖屏Activity、iOS声明通过 |
| 修正签名后的Android debug构建 | 48成功26.9秒；最终49使用校验脚本构建成功21.6秒 |
| 正式图标及最终50 | 29个唯一资源SHA与来源一致，iOS所有PNG尺寸正确且RGB无alpha；50构建成功9.5秒，APK内图标已抽取查看 |
| 打包配置防回归 | 缺少四项签名字段的合成配置在Flutter构建前拒绝；正向脚本48构建SHA与实际安装包一致 |

日志保存在忽略目录 .local：dev-zys-tests-final、dev-zys-final-affected-tests、dev-zys-delivery-journeys、dev-zys-latest-voice-tests、dev-zys-native-tests-final、dev-zys-final-analyze、dev-zys-final-openspec、dev-zys-delivery-build。中途错误测试路径和小屏协议勾选失败已重新定位并重验，不计为成功。

## 包与安装

- 包名 com.vvtech.aiassistant.dev，versionName 1.0.51-foundation，最终versionCode 50；关闭 ENABLE_MIGRATION_PREVIEWS，入口 lib/main.dart。首包47遗漏四项C1签名define，出现模型/接口不可用，已废弃为交付包；保留该失败证据。48修复连接，49纳入最终来源快照，50增加用户指定品牌图标。
- 普通API：https://chakenai-dev.vvtech.tech/aiassistant-api/
- SDK API：https://chakenai-dev.vvtech.tech/aiassistant-sdk-api/
- Agent、ASR/TTS及实时运行路由基址：https://chakenai-dev.vvtech.tech/aiassistant-runtime/；具体路径沿现有适配器，不指向本地或202数据库。
- 三个完整基址与四项非空签名配置已从最终APK内 kernel_blob 核对，仅输出布尔值；配置来自原被忽略的.local/cloud-dev/device-defines.json，不输出或提交凭据。
- 交付副本：D:\work\04phoneAgent\_isolated\phone-local-runtime\dev-zys-merged-20261010-v50.apk。
- SHA256：1d983622f02448ac0ada78912c9e517bb328c708f1847434c2f7192abb12698b。
- 当前 KOZ-AL00 通过 adb install -r 返回 Success；未卸载、清数据或跑会卸载的 driver。
- 首次安装时间保持 2026-09-18 12:54:52，最终更新时间 2026-10-10 11:48:30；安装后复核50，MainActivity前台启动成功。首次UI抓取返回null root，核对当前状态后有限重试成功；48安装后打开中的对话仍显示旧加载失败，完整重启后重新读取成功。未触发短信、登录、外呼或上传。
- 最终手机首页/任务tab可见，首页模型语义为QwenOmniPlus ×1.0；只读VM核对模型目录非空、loading=false、error为空。未输出账号令牌、对话或诊断密钥。SDK带签名公开首页配置只读探测HTTP200/code000000；未带账号令牌的Agent及Runtime探测401为鉴权拒绝，不当成服务宕机或登录成功。
- 使用 scripts/build-task-dev-apk.ps1 -BuildNumber 50 构建；脚本只验证固定SDK、批准基址和四项签名字段，不写入业务请求或私有配置。

## 用户追加应用图标

Android正式资源直接来自App v71的55084b34：各密度ic_launcher/ic_launcher_round、自适应XML、前景及白底颜色；AndroidManifest新增roundIcon。iOS按现有Contents尺寸只读复制历史正式iOS a4e8efe4967efc436a7e750929741b0e1db8fd25 的AppIcon对应PNG（同一蓝紫渐变声波品牌），未重画、缩放或改动旧仓库。共29个唯一资源，源SHA逐一核对；iOS无alpha，1024营销图及全部现有尺寸正确。APK实际使用自适应资源，xxxhdpi打包图已抽取目视核对。没有Mac环境，iOS资源完成不代表本次iOS构建/启动器验收；图标批次无Dart变化，不重复全量回归。

## 最新独立App对照

只读fetch独立aiassistant-app后，origin/v71更新到55084b34f85d4a2dd77650e0de833cbf08e66867，原v4工作树保持不动。NetworkModule.kt区分SDK HTTP、Agent SSE HTTP及Runtime WSS；SdkC1SigningInterceptor.kt/AuthRequestSigner.kt使用HMAC-SM3、设备上下文和Bearer token参与规范串。Flutter ServiceRoutes/C1Transport/C1RequestSigner沿同一契约，域名继续采用用户批准的chakenai-dev，不自动切换App其他flavor域名。

| 能力 | 最新App源码 | Flutter实际路由 |
| --- | --- | --- |
| 模型目录/选择 | network/SdkAccountSettingsApi.kt | SDK api/account/settings/realtime-call-provider，GET/PUT |
| 时延 | network/TaskApiService.kt | Agent api/assistant/realtime/call-models/latency，GET |
| 任务编排 | data/service/AssistantApiService.kt | Agent api/agent/chat/stream，POST SSE |
| ASR | features/assistant/speech/qwen/QwenTaskAsrSocketClient.kt | Runtime /ws/assistant/task-voice/asr，WSS |
| TTS | features/assistant/speech/qwen/QwenTaskTtsApiClient.kt | Runtime /ws/assistant/task-voice/tts，WSS |

本次网络故障为客户端构建遗漏，不要求后端改动。旧待确认监听票据/媒体返回问题仍独立保留，不以模型恢复代替外呼验收。

## 待验与风险

这次真实手机证据为保留数据安装、版本、启动和首页模型读取，不等同全部页面功能验收；没有读取或验证令牌内容。Windows 两项 Dart 与两项原生测试保持失败记录，应在有符号链接权限或原生目标环境重验。当前无 macOS/Xcode，未构建或安装 iOS；incoming 历史iOS验证记录不冒充本次证据。

真实电话、监听媒体、ASR/TTS、后台保活、可信SDK私有配置与认证、APNS/冷启动/Live Activity、生产签名升级和数据迁移尚未做本次运行验收。后端运行态与之前重复编排问题仍参考 CONVERSATION_DUPLICATE_TOOL_DIAGNOSIS_20261010.md，本次不修后端。正式升级不能使用此 foundation debug 包。
