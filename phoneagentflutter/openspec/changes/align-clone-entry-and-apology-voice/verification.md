# 集成验证

## 基线和范围
Flutter快进origin/codex/dev b29853ac后恢复本轮工作，无冲突。Native参考feature/test_v1.6.0 8f23592。误操作的本地340bf658从未推送，已安全撤回；后续只按用户授权同步更新后的codex/dev。没有部署Java/Web、改写数据库或擅自安装应用。

## 失败回归与审查
两个真实Shell声音克隆按钮先复现无权益仍进入模型选择，读取当前会员快照后，入口/升级/账号生命周期9项通过。道歉首次确认、缓存输入、候选非激活确认、连续切模、历史恢复、真实拨号倒计时、取消旧流、ASR来源及请求字段均有定向回归。新增API测试校验实际URI带activate=false，确认模型及asset必须匹配。

独立审查初版发现倒计时消耗、恢复spec派生字段、恢复任务身份、本地旧提示延迟播报和业务异常语义丢失，均已修复。审查者独立执行7文件38项通过并APPROVE。后续模型面板显式选择/普通关闭及原双端共5项通过；首次模型加载不触发恢复任务切模。

主Controller原事件提交/状态/观察接线独立到conversation_event_binding，仍508行；架构阈值未放宽，架构四项通过。中文UTF-8复读及diff检查通过。

## 构建前证据
analyze无问题；OpenSpec160项通过。真实Release/product Dart AOT探针接受test三条HTTPS路由；PowerShell首次-D参数解析失败后核对输出不存在，改Python参数列表编译运行通过。只读测试库确认SDK/Agent各唯一启用并对应com.vvtech.aiassistant.test，不输出凭据、不写数据库。脚本PlanOnly检查通过。

当前华为设备安装2026101504；最新codex/dev文档已有其他设备开发包2026101510，故本次选择严格递增2026101511，versionName1.0.51，使用已登记签名test Release ARM64。尚未安装设备，不以源码/自动测试代替人脸、短信、支付、外呼或邮件真实验收。

## 全量与最终产物
首轮全量：5693通过、2跳过、27失败。与本轮相关的15项已修复：OCR标题2项、旧重试按钮断言6项、memory notice投影1项、普通会话额外模型请求1项、克隆路由会员快照fixture5项。补验8文件39项通过。另对道歉任务模型作用域补失败回归：选择B模型不写账号默认A；只在道歉绑定存在时订阅模型变动，避免普通会话额外请求。

其余12项在未修改的b29853ac基线以相同4文件重跑复现（10通过、12失败）：voice_transport_preview 3项、domestic_model_sheet 6项、translation_persistence_pages 2项、local_translation_recording Windows混音文件锁1项。本轮不扩大修复范围，也不宣称全量通过。

最终联合回归41文件246项全部通过（56.9秒），覆盖真实Shell入口、道歉、会话/语音/历史、任务编排、联系人、确认门禁、积分订阅及OCR。最终analyze无问题，OpenSpec160通过；UTF-8、主Controller508行、diff检查通过。证据日志：D:/Temp/phoneagent-skill-parity-final-targeted-20261015.log、phoneagent-skill-parity-full-20261015.log、phoneagent-skill-parity-baseline-unrelated-20261015.log。源提交及签名产物见下方实际交付回执。

## 实际交付

代码中文提交ec3dab6ce1c53dda8d8ebdb88e2e912eb1756696已普通推送origin/codex/dev，远端读回一致；源树干净后冻结构建，无并行Flutter测试。经规定脚本PlanOnly后沿批准的离线回退，先Flutter Release --config-only --pub生成注册器（无integration_test），再Gradle离线assembleRelease成功。

产物：D:/work/04phoneAgent/deliveries/skill-task-parity-20261015/Phone_Agent_TEST_1.0.51_2026101511_test_20261015_193149.apk，78,909,028字节；SHA256=96fccb665d42a573360b184eda326e86432d9339452a7b6726251880791bee4e。实际包名com.vvtech.aiassistant.test、版本1.0.51/2026101511、原登记证书MD5 ebd4c931de412bf5d9c3716815389097。AOT/仅ARM64/无debuggable/无调试kernel及Vulkan校验层、三测试URL/四私有凭据与批准文件匹配、邀请host/scheme、11个受保护原生库源字节一致全部通过；未夹带签名材料或defines文件。未安装，未触发真实业务。交付目录README、test-release-verification.json、SHA256SUMS.txt及三份测试日志保存回执。

用户随后明确要求安装到手机：重新枚举实体KOZ-AL00/AEUN9X1507G02040（排除模拟器），现装test1504签名SHA256与新包一致。adb install -r等待荣耀系统确认时读取新截图，只选择“允许本次安装”，未改安全设置。安装Success，实际读回1511/1.0.51，firstInstallTime前后均2026-09-09 19:36:22，lastUpdateTime=2026-10-15 19:34:56；启动Status ok、PID27540，前台MainActivity及首页截图核验。交付目录device-installation.json和device-after-install.png保存证据。未卸载/清数据或触发真实短信/认证/支付/外呼；首页启动不代替业务验收。

## 1511道歉入口灰屏修正

手机灰屏截图与Release日志“Another exception was thrown”确认客户端首帧异常。新增正式conversationControllerProvider入口测试，红测精确复现LateInitializationError: Local 'controller' has not been initialized：ApologyVoiceController.begin → binding._present → controller._publish → OCR.synchronize → provider.isCurrent读取尚未完成赋值的controller。上轮独立Controller回归未覆盖正式OCR接线，首页启动验证也未进入道歉。

仅修改Flutter conversation_providers.dart：controllerReady在构造前false、完成赋值后true，OCR当前性判断先检查就绪，再核验owner/账号。正式Provider测试验证首屏确认卡可见、构造后OCR可进入、关闭后仍拦截。补登录态夹具时曾缺WidgetsBinding/网络事件端口，已显式使用测试binding及NoNetworkAvailabilityEvents，不改变生产逻辑。10文件39项通过、analyze无问题、OpenSpec160通过；计划签名test Release1512并保留数据覆盖安装，逐页进入道歉验证。未改Java/Web、接口/数据库或提示词。

1512实际回执：源码1195b991已普通推送origin/codex/dev并读回一致；与通讯录路由修复联合22文件150项通过，另提示界面8项通过，analyze无问题/OpenSpec161通过。干净源码冻结后构建test Release ARM64 1.0.51+2026101512，登记签名与成包全部核验通过。产物D:/work/04phoneAgent/deliveries/apology-entry-fix-20261015/Phone_Agent_TEST_1.0.51_2026101512_test_20261015_195411.apk，78,909,028字节，SHA256 8dfbe692238dfc339c5faa277702dd88fe8728ef00cebb0b388f8cf72c1e9fab。

实体KOZ-AL00新旧签名相同，install -r Success，读回1512，firstInstallTime仍2026-09-09 19:36:22、lastUpdateTime19:54:51、PID9705。随后新截图实际观察道歉确认卡及QwenOmniPlus没有可用音色提示均可见，灰屏消失；本进程未检出Flutter简化异常行。未宣称有克隆音色、未由agent提交道歉任务/外呼。device-apology-entry.png及device-installation.json随包，不把首页启动当成此入口证据。
