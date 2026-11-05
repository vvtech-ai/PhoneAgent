# 最近通话共享交互：实现与验证

日期：2026-09-17。按用户批准先基于HTML/CSS和现有组件补交互，视觉后统一校准。

## 已实现与来源

固定v65 `4c781e3` 的 DialRecentCallModels/Policy、AssistantDialHistoryList、AssistantDialerStateHolder：系统记录和App翻译记录按source+id去重、倒序、最多20项，同号码不同通话保留。空输入显示历史，非空显示既有T9；选择只回填，空输入点击拨号仅回填第一条，无效号码不可选。不把任务列表冒充拨号记录。

共享模型/合并在domain，来源端口在data，独立加载和失败/晚到保护在controller，列表仅展示和回调；两处Route复用同一组件。翻译历史恢复当前模式下的国家和有效主叫语言，不开启翻译、不恢复记录中的被叫语言。格式保留v65今日HH:mm/昨天/M/d及跨年边界。账号epoch重建、前台重新加载、先清旧数据、双源独立失败、单飞、销毁晚到保护。

正式Android系统来源已由下方增量接入已授权读取，App翻译归档仍为明确notConnected边界；iOS/Web系统源unsupported，不调用系统记录API、不申请权限。未接来源不显示“暂无通话记录”冒充成功，不能靠演练源补数据。

显式MOCK使用保留的555合成号码；共享页面/控制器不变。普通拨号演练可继续进翻译配置，再返回；翻译配置/电话端口继承隔离scope，不读写正式偏好、账号、任务，也不拨号。页面常驻MOCK标记，配置明确为本次演练内存状态。

## 自动验证

- 新增17项：政策7、加载控制器3、Widget/路由7。覆盖来源/去重/同时间排序/20项、规范国际号、无效号码、时间格式、双源错误/撤权/单飞/销毁、普通/翻译空号回填和无电话调用、模式与语言恢复、MOCK跨路由隔离。
- `flutter analyze` 无问题；`flutter test` 全量642项通过。
- `flutter build web --debug`、`flutter build apk --debug` 成功。
- Widget覆盖320/390/430宽、1.3倍字体；真实控件绑定，不用坐标覆盖层。
- 浏览器localhost:8080保留既有登录：正式首页→拨号显示未接来源→显式MOCK→空号点拨号回填+1/2025550101→清空回历史→翻译配置→选择第二条回填+1/2025550103、我方日语/对方英文→关闭返回。未知号码为不可操作文本。没有短信、外呼或真实账号写入。
- 浏览器发现MOCK配置提示沿用正式“已保存”文案，已改为“仅保存在本次演练”，补Widget断言并重新跑全量检查和构建。
- 本批无原生代码/依赖变更，无新设备安装或iOS构建，不宣称双端真机通过。

## 设计追溯和待校准

现有engine-dial HTML/CSS和SVG不变，新增列表依据v65有效组件静态参数。`design/dialer/recent-interaction.json`保留来源、样式、状态、动作和资源说明。新行仅文字/徽标，无图片资产；既有键盘与3个SVG继续复用。SafeArea负责系统栏，不渲染设计系统栏；外层填可用空间，小屏可滚动。

历史列表暂复用建议列表180高上限，非v65的剩余空间weight布局；顶部间距、最终列表密度、字体、安全区和设备显示差异集中校准。截图只证明实际渲染和交互，未进行运行态设计量测/像素对比，不给虚假保真分数。

## 后续真实能力及集中验收

1. Android已授权CallLog读取已接；仍须按v65定位决定完成后申请READ_CALL_LOG，不提前弹权限。拒绝/撤权、系统返回刷新和机型差异专验。当前无权限申请按钮，避免新增行为。
2. App翻译真正归档后接来源与旧数据迁移，联系人快照/旧标题/联系人名称回退按原实现；不得在系统拨号交接或MOCK挂断时制造真实记录。
3. iOS只展示App记录；Agent任务详情属于既有任务入口，不能混进v65拨号最近记录。
4. 双端新包阶段安装后验证长列表滚动、字体放大、语言恢复、按键和返回；真实电话测试需专用号码及授权。

OpenSpec 2.8仅标共享交互完成；2.9真实来源、2.5双端验收和2.6总体验收归档仍未完成。

## 2026-09-17 Android已授权系统记录端口

- 证据：v65 DeviceCallLogDataSource/Mapper读取CallLog；AssistantCallsDialSheet把系统源与本机FinalCallRecordStorage翻译子集合并。再次确认后端任务列表不是这个本机来源，不复用远端task list伪装归档。
- 原生`CallLogChannel.kt`只承接load、后台查询必要id/号码/缓存姓名/时间并返回前20条有效记录；注册于MainActivity，Manifest声明READ_CALL_LOG。前后权限检查、null cursor/异常显式failed、撤权denied、close停止待返回结果。没有requestPermissions、上传或记录姓名号码日志。
- Dart `device_call_log_channel.dart`限制Android调用；iOS/Web不触发平台消息。非ready丢弃任何附带rows，schema错误交controller failed；归一化、去重和排序上限复用共享政策。既有前台重载会重新检查权限，不保留撤权前记录。
- 自动测试使用合成method channel，覆盖iOS/unsupported无调用、拒绝/失败丢弃rows、ready过滤/去重/上限、schema异常与平台失败无自动重试。测试不等于真实Android ContentResolver/OEM或运行期授权通过。
- 新增7项通道测试；首轮全量5个纯Widget场景未替换真实系统端口导致pumpAndSettle超时，给这3个测试文件显式注入unsupported来源后，14项页面专项及最终773项全量通过。analyze无问题，Web/Android Debug构建、19项OpenSpec与408文件格式检查通过；合并Manifest核对`.dev`包及READ_CALL_LOG声明。本批不新增浏览器视觉或设备证据。
- 集中人工验收：安装允许的当前debug包后，先保持未授权进入普通/翻译拨号，应显示系统记录未授权且不自动弹权限；后续按正式定位门禁完成授权，再返回前台应展示系统真实记录、同号码多次保留、选择/空号按钮仅回填不拨出。撤权返回后旧系统记录必须消失，App来源独立状态不得被清空。全程不得将真实姓名/号码存入测试fixture或日志。
- 本批不改变iOS原生代码、不接App归档/旧数据迁移/定位申请顺序，不把2.9整体标完成；尚无本批设备安装或真实记录读取证据。
