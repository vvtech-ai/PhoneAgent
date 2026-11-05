# 对话位置与开发者摘要：实现及集中验收

2026-09-18；settings-interactions 2.2d2。行为依据Android固定4c781e3、iOS参考ddb996a。先完成可操作页面/共享行为，视觉后校准；不是整个迁移完成报告。

## 核对结果

- `AssistantDeveloperPermissionPageHost`将`assistantUiState.locationAvailable/locationDisplayText`传入开发者页；`AssistantUserContextHolder`成功定位后先显示四位小数坐标，逆地理编码成功后显示地址。与翻译拨号的国家/区号不是一个状态，不能拿国家码替代。
- `AgentStreamHandler`和`AgentStreamActionRuntimeGraph`通过`currentFreshAgentUserContext`在普通轮次/动作续接时准备上下文；刷新TTL为2分钟，每轮等待上限10秒。失败或未授权保持上次成功值，不伪造新位置。
- Android `FusedLocationProvider`先读取已授权的当前位置（8秒、2分钟内，精确1500米/近似3000米），再尝试5分钟内最近位置（GPS500米、其他1000米），按年龄/精度择优。授权由原权限流程处理，不在后台偷偷弹窗。
- iOS `AILocationService`提供CoreLocation/CLGeocoder参考。Flutter采用同一Dart缓存规则和已授权取样边界，不复制旧全局单completion或坐标日志。系统逆地理编码可能使用系统厂商服务；未新增App自有HTTP定位接口或第三方SDK。

## 当前实现与数据路径

`conversation_providers` → `DioAgentGateway.userContextProvider` → `AgentContextBuilder.prepare` → `AgentLocationController.context` → `DeviceAgentLocation` → 双端`AgentLocationChannel` → 同账号内存快照 → 合并`userContext.lat/lng` → 原Agent请求。时间/权限续接见[上下文验证](AGENT_CONTEXT_VALIDATION.md)。

- domain `AgentLocation`验证有限经纬度/范围/非0,0，地址只用于本地摘要；发送按Android契约只补lat/lng，城市和区域交服务端补全。无位置时不加入假字段。
- 共享Controller单飞、单调时钟2分钟TTL、10秒边界；没有成功结果时下轮可重新读取。失败/拒绝保留本账号快照，账号代次变化销毁控制器、取消旧端口且清内存。位置不落盘，不进入诊断日志。
- Android通道只读系统授权，普通位置请求8秒失败后可用最近有效位置；9秒总截止，有坐标但地址失败仍交付坐标。旧同步Geocoder最多一项工作，不向阻塞线程无界排队；平台服务内部调用无法强制中断，但过期回调被请求ID屏蔽。iOS一次请求+可选逆编码，9秒截止；完成/取消/engine detach清理manager/geocoder。
- 提交前合并保留OCR、首轮skill/contact、工具action和幂等ID；等待结束后重验登录代次与cancel，退出不能造成晚到HTTP。普通页面关闭可让正在进行的有界取样结束、只更新同账号缓存；账号结束取消全部，不把页面关闭当后台外呼挂断。
- `DeveloperLocationSummary`仅观察该快照，打开设置不采样、不申请权限，不改变翻译国家/号码。`ConversationController`保持原500行，不追加平台或位置逻辑。

## 自动验证与隔离范围

- 新增16项：坐标严格校验/显示、无急切读取、TTL/失败、单飞/超时/晚到、销毁/换账号；通道Web不可达/无授权请求/非法值；实际Dio适配的OCR与工具命令合并、失败继续、取消和换账号禁止POST；320/430宽度共享摘要及父子容器隔离。
- 全量1617项通过；analyze无问题；733个Dart文件格式检查无变化；Web、Android Debug、Mac iOS Debug无签名构建通过；OpenSpec校验见本批提交记录。
- `tool/previews/agent_location_preview.dart`独立8102入口：显式MOCK，合成坐标/地址、未授权、失败和3分钟推进，复用正式Controller/摘要；不调用原生定位/账号/HTTP。浏览器已确认读1次坐标、缓存期不重读、到期第2次地址、失败第3次保留地址。
- 没有真实位置采集、权限变更、新短信、电话或设备安装；8080已登录实例与Mac保留解锁会话未变。构建通过不等于原生定位运行态验收。

## 集中真机验收

1. 获得阶段安装授权后，打开开发者页：仅看已有摘要，不能弹定位权限或自动读取；未获取显示“未获取到位置信息”。
2. 无定位授权时发一轮文字：正常调用后端，不夹带虚假坐标、不自动弹权限。后端权限工具提示可按既有流程授权；再发文字或工具续接后核对位置字段，但不要复制真实坐标到公共日志/文档。
3. Android分别验精确与近似授权、定位服务关闭、无有效定位、最近位置回退；定位慢时最多等待共享边界，不能让发送永久卡住。iOS验WhenInUse、拒绝/限制及逆地理编码失败，坐标有值时仍可展示四位小数。
4. 成功后两分钟内重复轮次应复用；过期重新取样。刷新失败按现状保留旧快照，页面不得声称这是刚获取的新位置。
5. 等待定位时返回/退出账号：前者不发迟到对话请求，后者不显示或发送旧账号位置；重进后正常取样。核对原生重复回调、资源清理和后台切换，不用Web MOCK证明真机通过。
6. 对话已有OCR、工具续接或首轮联系人上下文时核对原字段不丢；翻译的手选国家、可信国家缓存与位置摘要互不篡改。

## 仍未完成

- currentTime/permissionStatus已由2.2d3接通并自动验证，双端运行态仍需集中验收；历史废弃联系方式不因旧DTO字段存在就重新迁移。
- 列表清空：原`AssistantDeveloperDataModeActions`在Filled/Empty都会清账号App本地通话记录；只有Filled刷新后台任务，联系人按授权刷新或内存清空。`AssistantCallRecordState.clearForAccount`默认持久化空记录。尚需核对Flutter本地通话源与消费链，不能改成DELETE后台任务或仅清屏后假报成功。
- 权限重置会清模拟标记并重开翻译拨号/位置提示，不撤销OS授权；该消费者仍待完成。整个2.2及迁移目标未完成，不归档。
