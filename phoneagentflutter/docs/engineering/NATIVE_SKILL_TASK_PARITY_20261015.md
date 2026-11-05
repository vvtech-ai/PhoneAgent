# 首页 Skill 与任务编排同步

用户确认以原生 `aiassistant-app/feature/test_v1.6.0` 最新 `8f23592` 为行为对照，Flutter仅同步 `origin/codex/dev`，本轮集成基线 `b29853ac`。Android仍交付登记签名的test Release ARM64，不部署Java/Web、不擅自安装或操作真实外呼。

## 业务变化

| 能力 | Flutter 本轮处理 |
| --- | --- |
| 语音模型页及音色弹层声音克隆 | 统一CloneCreationRoute先读取当前会员快照，cloneEntitlements.enabled=false直接取消/去升级弹窗，不读模型选择、录音或身份；不按FREE名称硬编码 |
| 道歉新入口 | 本地确认是否使用克隆音色，未确认不提交任务；无音色展示其他可用模型或不使用；候选activate=false确认后重查 |
| 道歉持续对话 | callVoiceSelection随当前会话聊天和confirm_call.actionPayload发送；不修改默认音色；切模失效旧查询、暂停拨号倒计时，生成可重复选择的新卡 |
| 道歉恢复/拒绝 | 读取pinnedSkillId和taskCallModelId，恢复保留服务器选择，只在明确切模时重查；拒绝已开始任务取消旧流并等待对应task_cancelled；重试复用取消身份 |
| 对话提示 | 顶部简化恢复文案并保留具体业务含义与点击重试，中间重复长文案和按钮移除；真实服务错误仍保留恢复门禁 |
| 多路任务与普通提问 | ASK_USER标题与播报一致；精确消除同轮旧前言，保留无关独立回复；不修改ledger事实 |
| 思考 | 正式原生标题Phone Agent；meeting_notification_v2/business_event_invitation/sales_recommendation使用正在理解任务，其余AI思考中，不展示模型原始思考流 |
| raw final互动 | ASK_USER/SHOW_OPTIONS/MAKE_CALL_REQUEST及既有工具互动复用原处理器；signal/final同轮同工具在播报前去重；停止后不执行迟到互动 |
| 联系人Skill | 补实时翻译并预填联系人姓名/号码到统一拨号页；disabled仍隐藏，其他旧版兼容回退沿用户现行决策保留 |
| 确认卡 | 比较实际可见spec、tool及后续确认/回执；规范化恢复投影补出的字段，防止合法历史卡被误拦 |

## 已有能力核对

订餐、会议、活动邀约、销售推荐及大型会议使用通用skill首轮、opening和selectedContact接线，首轮只发送一次，恢复不重新启动skill。批次进度排序、停止身份、物理结束观察、最终回执等待和历史计费快照已存在对应实现，本轮不再复制状态机。完整证据表见 `openspec/changes/align-contact-translation-skill-entry/audit.md`。

服务端skill内容和业务工具属于Java/Agent，不能根据客户端开场白猜测线上skill版本。本轮没有修改或部署这些服务。

## 验证记录

两个真实Shell按钮从失败回归转绿；克隆入口及原权益门禁9项通过。独立审查对7文件38项验证通过。修复审查发现的倒计时、恢复spec、恢复身份、旧提示、业务错误隐藏和ASR来源边界；模型面板关闭/明确选择及原双端5项通过。道歉选择本次任务模型B时，账号默认仍为A、偏好写入0次。模型订阅只在道歉绑定启用，普通会话不额外请求模型。

最终联合回归41文件246项全部通过，analyze无问题、OpenSpec160项通过。首轮全量5693通过、2跳过、27失败，其中本轮相关15项修复后补验39项通过；剩余12项在未修改的b29853ac基线复现：语音transport preview 3项、翻译模型sheet 6项、翻译持久化2项、Windows翻译录音混音文件锁1项。没有宣称全量通过。详细日志见主变更verification.md；签名产物另记实际回执，不将自动测试表述为真实供应商验收。

当前现场华为手机读回仍为2026101504，包含上次修复的2026101507未安装。真实截图联系人请求异常没有该轮HTTP/SSE错误证据；本轮已修复的互动兼容路径不能当作现场异常根因结论。真实认证、支付、短信、外呼及服务端邮件投递未擅自触发。

## 签名包交付

源码ec3dab6c已普通推送origin/codex/dev并读回一致。冻结干净源码，Release生成插件后沿已批准离线Gradle构建，未并行运行Flutter测试。测试签名包为1.0.51+2026101511、com.vvtech.aiassistant.test、ARM64，78,909,028字节。原登记签名MD5 ebd4c931de412bf5d9c3716815389097；SHA256 96fccb665d42a573360b184eda326e86432d9339452a7b6726251880791bee4e。

产物位于D:/work/04phoneAgent/deliveries/skill-task-parity-20261015/Phone_Agent_TEST_1.0.51_2026101511_test_20261015_193149.apk。成包测试路由/凭据匹配、邀请配置、AOT/无debuggable、无调试kernel/校验层、11项原生库字节一致核验通过；同目录README和JSON回执记录环境及验证边界。不自动安装；该回执不代表真实设备业务验收。

用户追加授权后已安装当前实体KOZ-AL00：新旧登记签名一致，install -r成功，版本读回1.0.51/2026101511，首次安装时间仍2026-09-09 19:36:22；启动Status ok/PID27540、前台MainActivity并显示首页。仅确认荣耀“允许本次安装”，未改系统安全设置、未卸载或清数据。device-installation.json及截图随包，业务仍待独立验收。
