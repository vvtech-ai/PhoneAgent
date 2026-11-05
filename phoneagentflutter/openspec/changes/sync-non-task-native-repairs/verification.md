# 同步非任务原生修复：实施与验证

日期：2026-10-13。Flutter起点ab31098b，参考Android c040ca1至cb94bbd。本地codex/dev_zys，未提交推送。

## 已修改
1. 目录记录FAILED候选，选择时重新查询目录；失败候选重新走准入，处理中候选仍只读恢复。
2. 选择/重录确认/实际认证或录音复用前核对当前目录与报价。价格变化拒绝旧确认，更新选择页目录；生成请求仍绑定用户确认的原报价，不能静默接受新价格。
3. 候选短轮询上限后每15秒只读查询；查询失败可继续恢复，READY自动更新；旧账号/模型/请求/候选保护保留，关闭或流程失效停止观察。
4. 处理中禁止重录；保存录音勾选沿现有state保留。设置页完成事实包含READY+CHARGED候选。
5. Android可信SDK补齐23/020002协议、请求头/公共参数，在加密签名前规范可信域表单与multipart身份。应用包协议身份固定为com.vvtech.aiassistant；appKey与secret仍从现有安全配置读取，不复制参考源码明文凭据。真实配置与SDK服务验收单列待验。
6. sdk.jar同步参考固定副本（SHA256 79948c1ab28536cd6498ad852476390ce962b5423b0351def3a6f4aab6979198），含FormBody编码兼容；更新哈希检查及依赖说明。
7. 普通Android PCM输出补充开始/首次播放/首次队列排空的安全设备诊断，不记录身份、文本、音频或请求ID，不改变播放时序；通信模式不启用新诊断。

## 保留及排除
Flutter原有布局、颜色、字号、间距和共用控件保持。唯一widget行为接线是旧不可用克隆模型允许点击重新检查；错误/加载反馈使用原控件。未改对话、任务列表、AI代办、任务联系人/评分/文件卡、翻译电话或iOS可信SDK。
已存在的候选归属/generation隔离、认证失败恢复、可选录音确认闭环和网络/服务错误分类保留。明确MODEL_TIMEOUT的处理在排除的对话模块，未修改该模块，也未新增无调用方工具。失败标题、价格固定宽度等非必要Android视觉调整未迁移。

## 自动验证
- Flutter 3.32.0 / Dart 3.8.0，未升级工具链。
- flutter test test/features/voice_clone test/features/call_models test/features/trusted_caller test/core/audio test/core/network --reporter expanded --concurrency=8：826通过，0失败。
- 测试拆分后clone_fresh_admission_test及clone_flow_controller_test：31通过。
- flutter analyze：无问题。
- Android TrustedCaller定向JUnit：22通过，0失败/错误/跳过。
- 独立Java身份/表单编码回归：通过。
- flutter build apk --debug：通过。
- python3 tool/check_trusted_caller_apk.py build/app/outputs/flutter-apk/app-debug.apk：runtime哈希、AAR重复类、19个必需DEX定义及厂商Manifest检查通过。
- openspec validate --all：110通过、0失败。
- git diff --check：通过。修改手写源码及测试均不超过500行；流程controller为500行，准入策略单独放domain。
本轮为受影响模块及直接调用方定向回归，未执行全量测试。

## 工具恢复
首次直接Gradle使用终端Java11被AGP拒绝。读取日志并核实Android Studio JBR21后，单命令指定JAVA_HOME重试成功；没有修改系统JDK或Gradle配置。初轮569通过9失败为旧目录读取次数/完成状态断言；修正后587通过，新增准入接线及扩大回归826通过。

## 尚未验收
- [ ] 双端声音克隆页面实际显示、长等待返回READY及保存录音操作。
- [ ] 实际服务器准入/价格变化及认证录音复用联调。
- [ ] Android可信SDK配置、初始化、设置页及实际来电展示。
- [ ] 真实设备普通TTS音频路由、音量和播放听检。
没有真实认证/收费/来电测试授权，本轮未安装操作设备；构建与离线测试不作为真实业务验收。保留数据安装及用户验收完成前不归档。
