## 2026-10-16 单呼就绪与双端返回修复

- [x] 4.1 复现并修复纯实时字幕未触发自动滚动；验证Android/iOS、新字幕可见、重复话语及无新字幕回看位置保持。
- [x] 4.2 执行相关字幕/通话页面定向测试、静态分析和规格校验，构建新版dev APK并在当前Android手机保留数据覆盖安装，核对包名/签名/版本/安装时间与启动结果。

2026-10-16 字幕与安装补充：只读对照旧App a0bedb12 的 FinalAiCallPage.kt（LaunchedEffect(transcriptCards) → animateScrollToItem(lastIndex)），共享页面改以显示字幕内容触发平滑跟随，并在可变行高布局更新后继续对齐底部。Android/iOS小屏大字合成回归覆盖纯SSE、重复话语、历史回看与新字幕；相关15项测试通过，flutter analyze无问题，当前change校验通过。dev 1.0.51(2026101602) APK构建成功，签名与现装一致，adb覆盖安装Success、版本读回1602、firstInstallTime不变，启动Status ok且截图确认保留登录首页。安装回执位于.local/deliveries/dev-2026101602/installation-result.json；未执行真实外呼，iOS真机与整通验收仍归2.4。

- [x] 3.1 解码服务端 launchReady 并以明确 true 限制单呼页面入口；准备与失败保持会话，覆盖 HTTP DTO 与状态转换回归。
- [x] 3.2 按用户最新要求保留单呼通话页禁止返回，不增加返回按钮；验证 Android/iOS 返回限制、持续观察和零隐式挂断。
- [x] 3.3 完成定向测试、flutter analyze、OpenSpec 校验及任务/问题记录，区分自动验证与真实设备/外呼待验。

2026-10-16 验证：新增准备门禁测试先复现 REQUESTED/DIALING/CONNECTED 缺少就绪证据仍跳页的3项失败；修复后通话模块211项、系统导航/完整App调用方5项通过，flutter analyze无问题。真实HTTP DTO覆盖缺失、false、字符串true、数值1与布尔true；iOS使用存在上一层路由的CupertinoPageRoute验证边缘手势不退出，Android系统返回继续观察且无hangup。既有监听和完整App测试按最新禁止返回规则同步，明确挂断及远端结束退出仍验证通过。当前change校验通过；全仓OpenSpec147/150，3项既有无关变更缺失MODIFIED场景（incremental-validation-policy、login-presentation、native-feature-parity-audit），未修改其内容。dev票据表已按test补列和联合主键，86条原行内容核对一致，原1054查询成功；没有执行新外呼或安装新包。真实设备及dev整通验收仍归2.4，不归档。

## 1. 共享接口与状态基础

- [x] 1.1 核对固定v65控制/轮询/转写策略及后端NOT_FOUND协议，不迁移接管入口
- [x] 1.2 目标/快照/监听票据domain、AccountApi仓库与协议/账号隔离测试
- [x] 1.3 转写与终态等待策略，独立controller轮询/挂断/晚到/失败回归
- [x] 1.4 app仓库装配、analyze/test/Web/OpenSpec、实现与人工验收记录、提交推送

## 2. 端到端接入与验收

- [x] 2.7 实时自动确认与积分准入共享核心：v65请求身份/计价/首次与再次不足、账号隔离提示存储、幂等提示API、1500ms调度/取消/单次提交和回归；27项新增/669全量、analyze、Web/Android Debug、19项OpenSpec通过；不以核心完成代替2.1/2.2生产接线。

- [ ] 2.1 自动确认与积分准入、单路状态/统一页ledger结果同步接入；实时入口/发送前拦截/轮询终态同步、结构化SSE失败、实时结果直接协调及历史当前确认门禁已实现；剩余钱包缓存刷新/结算等见CALL_FLOW_VALIDATION.md
- [x] 2.2 正式单路通话页自动入口/关闭协调接入；复用2.6共享页面，多路不进该页；隔离Web连续流程与共享Widget验证通过，真实电话/媒体/设备不在本勾选范围
- [x] 2.3 监听媒体传输、平台播放与音源适配及可重复mock验证
  - 共享只读WS/PCM、有限重连/静音/账号生命周期、双端通信音源、正式三按钮及同页隔离演练；26新增/1972全量和三端构建通过，见CALL_MONITOR_VALIDATION。真实声音与设备安装归2.4，不归档父项。
- [ ] 2.4 阶段性Android/iOS真机与集中人工授权通话验收
- [ ] 2.5 用户验收后合并规范并归档
- [x] 2.6 共享单路页/转写/三按钮/音源弹层及隔离场景入口，静态设计先行、浏览器和自动验证
