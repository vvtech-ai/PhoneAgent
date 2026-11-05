# Tasks
- [x] 1. 核对需求、原生两个入口、Flutter现状和上下文。
- [x] 2. Android位置权限状态和历史申请记录一致化。
- [x] 3. Android拨号controller/host/dialog时机及设置返回，保留iOS。
- [x] 4. 位置卡片直接设置和返回自动检查，保留Flutter布局。
- [x] 5. 定向回归、analyze、OpenSpec、Kotlin与Debug编译，更新记录。
- [ ] 6. 用户与Android真机验收（未授权安装或真实外呼）。

## 微批实施
- 原生批：LocationPermissionPolicy、PermissionChannel、TranslationLocationChannel三文件；位置状态读取两种已有申请标记，其他权限逻辑不变。
- 拨号批：controller、host、dialog三文件；Android独立策略、说明框先关闭、settings不显示额外业务框，iOS保留默认策略。
- 位置批：location controller、App provider、DialLocationHost三文件；Android注入只读权限检查，卡片直接设置并在resumed自动刷新。
- 演练隔离批：通用位置演练显式注入纯模拟controller，防止新增权限读取依赖穿透到系统；原通用演练契约保留，Android新流程另有专门测试。
- 定向测试增加首次/重复进入/设置返回拒绝、卡片直达设置/自动获取/取消迟到/iOS旧路径；既有大字体和320/390/430弹窗外观断言保留。
- 首轮测试中旧Android手动返回断言和演练依赖穿透已修复；Flutter3.32生命周期测试API返回void，去除错误await。未改工具链或样式。

## 平台验证恢复
- 2026-10-19 17:20 CST，固定Flutter3.32/JDK17执行Debug构建，Kotlin/Java编译已完成，但:app:packageDebug因No space left on device失败；df核对仅118MiB可用。
- 首次清理调用因工作目录为android而相对路径不存在，无删除发生；重新核对绝对路径、输出大小和修改时间后，仅移除本次失败生成的build/app/outputs/apk/debug/app-debug.apk。保留既有flutter-apk、deliveries及其他任务目录。
- 准备执行Kotlin定向与ARM64 Debug有限重试，不将失败包当作交付。

## 最终验证
- Flutter3.32.0 / Dart3.8.0，flutter analyze无问题。
- flutter test --no-pub联合25个定向文件166项通过；追加blocked按钮文案用例后，位置卡片与权限UI两文件18项复验通过，去重共167项。本轮没有全项目回归。
- 包含dial_permission controller/UI/port、拨号动作/返回/国家页、Android位置流程、位置controller/channel/UI/诊断/加载/旧缓存、设置重置、设备权限通道、Shell权限/拨号、架构及前一轮Toast三文件。
- JDK17执行 ./gradlew :app:testDebugUnitTest --tests com.vvtech.phone_agent.LocationPermissionPolicyTest --offline 成功；XML实测4 tests / 0 failures / 0 errors。Kotlin daemon缓存异常自动回退后成功，未改编译配置或升级依赖。
- 初次全ABI Debug在打包时磁盘不足；本次失败产物按大小和时间核对后单文件移除。重试 flutter build apk --debug --no-pub --target-platform android-arm64 成功，当前build/app/outputs/flutter-apk/app-debug.apk仅为内部编译验证产物，不是测试Release交付，不安装。
- 构建前后HEAD为5b91fb7d，分支codex/dev，加本工作区未提交变更；固定Flutter/JDK17，无编译中切分支或并行Flutter测试。
- openspec validate --all为203项通过，git diff --check通过。当前修改手写文件均未超过500行。
- 未修改iOS平台文件/共用弹窗外观、真实系统权限和定位、真实外呼/收费均未执行；用户及Android真机验收待完成，未提交推送或归档。

补充成包核对：Debug ZIP校验通过。命令指定Flutter target android-arm64，但供应商AAR仍携带arm64-v8a/armeabi/armeabi-v7a/x86/x86_64目录；本次未改SDK打包规则，也不宣称此内部Debug产物满足测试Release的仅ARM64交付门禁。

## 2026-10-19 提交前影响复核与授权
- 用户在知悉影响分析后明确要求Git提交并推送远程；本次保存当前两项实现，不额外执行此前仅提出、尚未批准的范围收窄方案。
- 复核36ab5f3a..5b91fb7d后的有效38个测试文件：312项通过、3项失败。translation_pages_test的非法号码断言仍期待旧文案，尚未同步；translation_setup_test两项默认语种断言失败，控制器/依赖/测试与已提交HEAD相同，本轮未修改该逻辑。首次历史列表包含一个已删除测试文件，已排除后复验，不计业务失败。
- 已知间接影响保留并向用户说明：普通拨号非法号码也改共用Toast及中国手机号文案；共用PermissionChannel.resolve(location)读取合并的申请记录，可能更早返回blocked。未执行隔离普通模式或恢复任务对话旧判定。
- 后台模型语种过滤、默认语种算法、位置未确认入口仍保留；不把源码保留等同全部场景验收。用户/真机验收与上述失败待处理，OpenSpec不归档。

## 推送前集成验证
- fetch发现origin/codex/dev新增d677f258，保存本地修改后将未发布提交rebase到该远端版本；保留远端对话输入、会员套餐、认证限额和国内扣分反馈。
- 冲突仅根任务/问题记录及TranslationSessionRoute；文档保留双方新增段落。路由保留失败Toast和服务端确认的结算Toast，共用队列分别展示；controller保留远端settlementNotice生成规则。
- 新增正常结束/失败结束同时带结算回执的路由回归，验证退出后仍显示、重复终态不重复入队。
- 集成后19个定向文件150项通过；flutter analyze无问题，openspec validate --all 204项通过，diff检查通过。包含远端对话/会员/认证测试和本轮翻译/权限/共用Toast/架构测试。
- 前述38文件补测中的3项失败及两项间接影响仍待处理，未纳入额外修复；本次未全量回归、重新打包、安装或真实外呼。此前Debug验证属于集成前记录。
