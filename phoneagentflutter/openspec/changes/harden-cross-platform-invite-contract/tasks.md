## 1. 规格
- [x] 1.1 核对当前分支、规则、需求和邀请 active change。
- [x] 1.2 OpenSpec 全部校验。
## 2. 实现
- [x] 2.1 手工邀请码注册稳定身份、来源隔离及恢复测试。
- [x] 2.2 完整活动快照、清旧状态及事件周期测试。
- [x] 2.3 刷新合并、操作结束刷新及迟到响应测试。
- [x] 2.4 AIAssistant1 活动/注册提示、错误白名单和 iOS 欢迎策略回归。
## 3. 验证
- [x] 3.1 定向 invites/auth、双平台展示及入口/海报/奖励回归、analyze。
- [x] 3.2 OpenSpec/diff/文件行数及更新根任务、问题记录。
- [ ] 3.3 Android/iOS 真实链接、相册及注册奖励验收；手工注册响应丢失后端重放待核，未验不归档。

- 注册微批：AuthController 与 PendingInviteController 两文件，手工邀请码提交也持久请求号，键包含实际来源，保留原 REFERRAL 键及普通登录。测试批随后执行；后端只读核对 register 强制请求号、登录重放缓存仅显式 REFERRAL，手工丢响应仍列服务端待核。

- 快照/刷新微批：codec、活动Controller、独立活动提示三文件；拒绝缺活动发码，原子发布完整快照，刷新清旧，忙碌刷新合并，设备操作事件取code周期且不阻塞后续刷新。测试单独批。测试patch首次上下文不匹配，已重读实际文件后一次修复，无重复副作用。

- 提示微批：Repository白名单和注册InviteFailure两文件；新增ACTIVITY_DISABLED/ACTIVITY_UNAVAILABLE透传，注册文案按AIAssistant1，活动独立映射。欢迎页实现未改，iOS继续白名单保留。注册专项10项通过。

- 自动验证记录：注册专项10通过。快照/API/flow首轮19通过、1文件编译失败，新测试使用了错误个人进度字段且test.fail与继承字段重名；按实际domain改为successful并显式this.fail。首次修正误用count，已再次核对字段纠正。analyze首轮对应2项测试错误，不是生产错误。机械格式化11文件无UI改动，待复验。

- 邀请/auth整模块首轮389通过、2失败，均为环境链接测试发码夹具缺活动快照；已按新协议补完整合成活动，未放宽生产校验。新快照10项、提示30项均已包含389通过，analyze末轮无问题。双主题窄屏2倍字号错误→重试恢复通过，不代表真机。

- 周期身份边界微批：codec单文件先校验periodId缺失/空白并分类INVITE_ACTIVITY_CHANGED；API测试独立批补三个截断快照用例。保持非法活动结构安全拒绝，不改变activity查询的兼容空态。

- 最终源码定向回归：invites/auth/architecture共398项通过（25秒），包含新增缺周期与双端提示/恢复、既有入口/海报/奖励。详细范围和后端手工丢响应边界见 docs/engineering/CROSS_PLATFORM_INVITE_CONTRACT_20261015.md。未改平台/依赖，不重打双端包、不安装；真实设备/注册奖励仍待验。

- 收尾：analyze无问题（4.7秒），OpenSpec153通过/0失败，diff/UTF-8/修改Dart文件500行检查通过。代码与自动测试完成，3.3设备/真实注册及后端重放核验保留待验；无归档、提交或推送。
