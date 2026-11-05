## ADDED Requirements

### Requirement: 授权事实必须归属当前账号与号码
系统 SHALL 以账号、号码和登录代际冻结可信来电owner。仅当前owner一致且SDK明确确认的报告可显示authorized；点击、页面展示、配置就绪及未知结果均不得当授权成功。

#### Scenario: 打开组件后尚无授权结果
- **WHEN** SDK设置已打开但尚未明确返回授权事实
- **THEN** 保留已核验状态，返回后重新读取，不提前持久化授权成功

#### Scenario: 账号或号码在操作期间改变
- **WHEN** 初始化、读取或打开页面仍未结束而owner已改变
- **THEN** 作废迟到状态和后续显示，不把旧账号报告写入新账号

### Requirement: SDK缺失必须在设备业务前拒绝
系统 SHALL 把缺少已许可SDK或安全配置展示为不可用，保留退出及重试读取，不自动申请SIM/电话/推送权限、不伪造号码或证书。

#### Scenario: 配置尚未部署
- **WHEN** 用户打开可信来电入口但组件不可用
- **THEN** 显示明确不可用，不执行初始化外部业务或宣称授权完成

### Requirement: 平台流程必须保留有效差异
共享设置卡和状态反馈 SHALL 统一；Android SDK首次/后续设置与iOS有效首次说明、后续设置及来电扩展 SHALL 分别适配，不向iOS复制默认拨号器或悬浮窗能力。

#### Scenario: iOS首次设置
- **WHEN** 已配置iOS组件且当前账号尚未看过有效首次说明
- **THEN** 显示首次说明并由用户开始进入组件，不以旧测试文本删除有效说明

### Requirement: SDK必须使用工程内固定副本并区分环境
系统 SHALL 将用户提供的测试/正式iOS SDK复制到工程专用Vendor目录，Android使用固定原生SDK的工程内AAR副本；构建不得引用提供的iOS_SDK路径或原生工程。副本 SHALL 校验来源/字节一致性并记录版本，vendor生成模块单独标记。测试与正式环境 SHALL 选择相应SDK，冲突或缺失不得猜测运行。

#### Scenario: 提供目录移除或路径变化
- **WHEN** SDK已复制并接线后提供目录不再存在
- **THEN** 构建只读取工程内副本，不回退到原提供路径

#### Scenario: 环境不匹配
- **WHEN** 当前环境与选定SDK不一致或副本缺失
- **THEN** 在SDK初始化及真实授权之前拒绝，不静默使用另一套SDK

### Requirement: 首次说明记录必须独立于授权事实
系统 SHALL 在iOS有效SDK初始化后报告当前账号是否需要首次说明，首次展示请求成功后按环境/账号保存guideSeen。记录说明、点击开始和返回 SHALL NOT 改变已核验授权事实；Android由有效SDK首次/后续UI适配，不重复显示iOS说明。页面或账号已作废时 SHALL 拒绝迟到的说明记录响应和SDK打开。

#### Scenario: 首次说明后取消
- **WHEN** 当前账号首次说明已按有效请求记录但用户返回
- **THEN** 保持原授权状态并关闭说明，不自动打开SDK，后续入口按已看过说明处理

#### Scenario: SDK报告冲突或不能确认授权
- **WHEN** SDK成功响应没有明确授权字段，字段未知或彼此冲突
- **THEN** 仅报告组件可配置，不猜测授权成功

### Requirement: 已配置可信入口必须一次进入有效原生流程
系统 SHALL 在本次可信卡入口初始化/读取就绪后只自动打开一次有效说明或SDK设置，不增加成功分支的额外确认点击。说明取消及SDK退出后 SHALL 返回设置首页并核验状态；刷新和前后台恢复不得自动重开。组件不可用或操作失败 SHALL 保留明确反馈、退出及手动重试。

#### Scenario: 有效SDK退出后状态刷新
- **WHEN** 当前owner的SDK设置已退出并完成状态回读
- **THEN** 返回设置首页，不因状态就绪再次自动展示SDK页面

### Requirement: iOS推送绑定必须按账户串行隔离
系统 SHALL 将推送绑定独立于设置surface，以账号、号码、登录代际、环境及APNS token冻结请求。通知允许且token格式有效才可绑定；换账号或通知撤权 SHALL 先确认旧绑定解绑，迟到绑定成功亦先补解绑。未知或失败结果 SHALL 阻止新绑定并保留显式重试，不把超时当服务端解绑成功，不将token传入Dart或日志。

#### Scenario: 旧绑定完成时账号已改变
- **WHEN** 原账号绑定请求返回成功而当前owner已改变
- **THEN** 对原绑定执行解绑并确认后，才允许当前账号绑定

#### Scenario: 解绑结果未知
- **WHEN** 旧绑定解绑失败或未获得确认
- **THEN** 不启动新账号绑定，保留待重试状态

### Requirement: 来电身份必须验证且隔离事件代际
系统 SHALL 使用固定iOS精确push字段提取身份验证请求，called规范号码必须匹配当前owner。token SHALL 只存native内存，不传Dart/日志；只有SDK明确验证成功才能显示验证通过和凭证。账户、号码、登录代际改变、来电结束或新事件 SHALL 作废旧请求及迟到结果。未知字段不得覆盖身份验证事实。

#### Scenario: 解析期间账号改变
- **WHEN** 旧账号SDK解析返回成功但当前owner或事件代际已改变
- **THEN** 丢弃旧结果，不展示或持久化旧凭证

#### Scenario: Activity时间缺失或异常
- **WHEN** callTime缺失/非法、超过20分钟或未来超过60秒
- **THEN** 不创建来电Activity，不将异常时间当新鲜身份

### Requirement: LiveActivity必须采用当前已验证身份及公开平台门禁
系统 SHALL 以native白名单verified且新鲜的当前owner/event构建独立LiveActivity，编码总量不得超过4KB。App前台且iOS16.1以上系统允许才可用公开API创建本地活动；后台push-to-start SHALL 依赖另行确认的可信服务端契约，不使用私有回退或把普通通知接受当验证。独立扩展 SHALL 保留测试/正式App身份前缀和Flutter构建版本，App部署基线保持15.5。

#### Scenario: 账号或当前来电结束
- **WHEN** 当前owner作废、身份失败、当前来电结束或超出新鲜窗
- **THEN** 清理本功能活动并拒绝迟到创建，不影响其他业务活动或页面

#### Scenario: 用户明确点击当前活动
- **WHEN** 固定scheme/host及唯一eventId匹配当前新鲜已验证事件
- **THEN** native递增展示版本且保留验证event id，Flutter可以再次展示凭据
- **AND** 旧URL、额外身份字段、旧页面关闭和低版本迟到均不得改变当前展示

### Requirement: 冷启动待恢复通知必须有限且不提前验证
系统 SHALL 仅在当前consumer第一条账户状态到达前保留最多一条白名单原生内存通知，25秒后清除，不持久化token或初始化SDK。首次账户恢复后 SHALL 再校验called号码和新鲜时间；nil账户、号码不符、引擎替换、来电结束均清除，不把缓存接收当身份验证成功。

#### Scenario: 通知先于首条账号状态
- **WHEN** 当前consumer接到结构有效且新鲜通知但尚未恢复账户
- **THEN** 仅短暂保存白名单，系统完成回调报告未验证
- **AND** 恢复账户后匹配号码且未到期才启动既有SDK验证

#### Scenario: 首条账户状态为空或恢复过晚
- **WHEN** 首条账户为空或缓存已经超过25秒
- **THEN** 丢弃通知，不初始化SDK、不显示凭据

#### Scenario: 冷通知的号码字段为非布尔数字
- **WHEN** 新鲜通知targetNumber使用正常payload已支持的非布尔数字
- **THEN** 结构缓存采用同一字符串提取规则，恢复后再核对当前owner
- **AND** 布尔号码拒绝，结构有效不表示身份验证成功

### Requirement: 可信SDK页面遵循工程竖屏范围
Android宿主 SHALL 为固定工程SDK的所有原生Activity声明portrait，保持SDK副本字节不变；iOS保持既有iPhone/iPad竖屏声明。系统权限/角色页面 SHALL 按系统行为处理，不扩张到外部系统Activity。

#### Scenario: Flutter进入可信原生页面
- **WHEN** 构建并进入固定SDK首次引导、设置或子页
- **THEN** 宿主工程为SDK Activity保留明确竖屏配置
- **AND** 构建/manifest证据与真实设备旋转验收分别记录

### Requirement: iOS设置窗口必须绑定原生当前账户
iOS SDK设置surface MUST 仅接受当前engine已同步完整账户的请求，账户变化或签出立即关闭旧窗口并作废旧请求，登录代际 MUST 非负。

#### Scenario: SDK初始化期间账户变化
- **WHEN** 初始化完成前账户任一字段变化或签出
- **THEN** 旧请求以作废结束，迟到初始化不得使旧surface就绪
- **AND** 旧engine不能更新当前账户或打开新窗口

### Requirement: 共享账户准入必须先于设备通道
共享Dart账户 MUST 拒绝负loginEpoch及账号或号码中的C0/C1控制字符，非法账户 MUST NOT 进入SDK账号或设置MethodChannel。

#### Scenario: 无效账户点击可信设置
- **WHEN** 账户含控制字符或负登录代际
- **THEN** 本地拒绝请求且不调用原生设备通道

### Requirement: iOS SDK环境必须显式装配
iOS SDK环境 MUST 仅由显式0/1构建宏映射正式/测试，缺失或非法宏 MUST 返回不可用并拒绝读取私有凭据。

#### Scenario: 自定义构建配置遗漏环境宏
- **WHEN** SDK环境宏缺失或不是0/1
- **THEN** 不默认正式环境，不读取AppKey/AppSecret且不初始化SDK

### Requirement: 账户签出必须是显式请求
iOS SDK账户通道 MUST 要求显式owner字段；只有null代表签出，合法账号只含accountId/phone/loginEpoch，环境必须匹配当前test/pro配置。畸形请求 MUST 在变更设置、推送或来电状态前拒绝。

#### Scenario: 请求遗漏owner
- **WHEN** 请求仅含environment或owner结构不完整
- **THEN** 返回安全错误且不把请求当作退出账号

### Requirement: 不可用提示不得推断未确认原因
共享可信来电状态反馈 SHALL 在prepare仅返回不可用布尔结果时使用中性环境不可用提示，不将不支持的平台或模拟器推断为用户未部署SDK配置。

#### Scenario: 不支持的平台返回不可用
- **WHEN** Web或不支持的平台在设备访问之前拒绝prepare
- **THEN** 展示当前环境可信来电不可用，禁止打开设置且不声明已授权或配置缺失
