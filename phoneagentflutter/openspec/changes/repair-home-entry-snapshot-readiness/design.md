## Decisions

HomeRepository.load 保持签名，语义改为读取本次有效快照，HTTP 后台单飞写回；缓存校验仍使用同一 mapper。后台失败被消费并保留缓存；关闭后不能再写入。缓存存储慢时 HomeState 默认完整随包入口仍可点，不新增等待或重试门禁。

HomeController 收到快照先发布；标语轮换异步执行，生命周期检查阻止已销毁 controller 更新。后到 HTTP 不发布到当前 controller；下次 load 可读取新版本。导航已将 card.opening 复制到 ConversationEntry，不再添加第二套入口状态。

完整随包卡片及开场都来源于 `test/v66.0.3@a0bedb12`：HomeConfigDefaults 与 `backend/src/main/resources/skills/restaurant-booking.md`、`meeting-notification.md`、`event-invitation.md`、`sales-recommendation.md`、`meeting-notification-v2.md` 的 opening frontmatter。道歉仍走专用 Consent；显式无开场的 generic/translation 保留原规则。

Mapper 对 enabled 普通 openSkill 缺开场判为无效整份快照，回退完整缓存或随包内容；不得拿普通开场授权模型、会员或电话执行。字段完整性、签名/ETag、304、缓存与旧请求失效均以真实 repository + 可控外部端口验证。

文件分工：defaults 只负责已确认随包内容；mapper 只负责结构与完整性；repository 负责公共配置缓存与后台单飞；controller 负责快照发布和 slogan 生命周期。每批最多三生产文件，独立 OpenSpec，不改其他任务文件。
