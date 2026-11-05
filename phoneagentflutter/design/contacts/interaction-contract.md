# 联系人交互契约（静态优先，非视觉验收）

来源：设计固定 `0cd58de9` 的 memory/index.html、css/style.css、js/contacts.js；业务固定 `4c781e3` 的 AssistantContactsPage、AssistantContactDetailPage、AssistantContactRemarkEditor、AssistantContactSkillPolicy、AssistantContactSkillOpeningPolicy、PendingSelectedContactTurnContext。2026-09-17 用户批准现有 HTML/CSS/组件优先；未采集本批运行态 computed style，不用缓存错配截图验收。

## 页面、状态、控件与路由

| 页面/控件 | 状态与事件 | 目标/副作用 |
| --- | --- | --- |
| 联系人 Tab | 原生首次无权限、拒绝、受限、部分授权、加载/失败/空/有数据 | 仅显式授权按钮请求系统权限；恢复前台重新检查；刷新不主动申请权限 |
| Web 演练入口 | 浏览器不可读取通讯录 | debug 下主动开启 MOCK，联系人与目录同时为内存数据；退出清空 |
| 联系人行 | 同名不同号码独立显示 | 进入所选记录详情；返回列表 |
| 详情备注卡 | 加载、独立加载失败重试、空、已保存 | 不以目录项替代系统列表；编辑弹层 |
| 编辑备注 | 输入最多 2000 字、取消、保存中不可重复/退出、失败保留草稿 | 成功匹配返回值后关闭；空值清除备注；不修改其他资料字段 |
| 拨打电话 | 显示平台能力状态 | 系统拨号与 AI 外呼分开；Web 演练不拨号；原生拨号适配仍待接入 |
| 发起任务 | Skill 列表加载/空/可选/返回 | 沿 v65 仅启用的 OpenSkill，排除翻译/通用入口；选中进入统一页，首轮携带 CONTACT_DETAIL，Web 必须隔离 Agent |
| 统一页 | 默认语音、切文字、发送/回复/返回 | 复用正式页面与控制器；MOCK 不发网络命令、不写历史、不触发外呼 |

## 组件与静态参数

- ContactAvatar：列表 42px / 详情 88px，初始字母为设计文字，渐变 #7AA8FF → #4F7DFF。
- ContactsPage：行竖向 padding 14px，头像间隔 12px，名称 16px，号码 13px；保留底部导航空间，不增加旧搜索功能。
- ContactDetailPage：详情姓名 31px/800，号码 15px，备注卡 16px 内边距，双按钮并排；内容滚动和底部操作分离。
- ContactRemarkEditor：原生 TextFormField，多行、2000 字限制、保存/取消。使用现有主题和键盘避让，不以图片代替输入控件。
- 返回箭头复用 `assets/images/identity/identity_0.svg`（已在 pubspec 注册的原始 SVG）；头像用布局/文字，不创建伪图标或引入图片背景。
- Skill 弹层复用 ListTile/Sheet 组件，正文和动态数据来自实际 HomeConfig；可用性以 v65 策略为准，不迁移设计中的亲属/组织/记忆入口。

## 待统一视觉校准

渐变角度、卡片透明度/阴影、弹层曲率、字体平台差异、原型 Skill 行图标、详情双 CTA 精确高度与列表分隔线。上述为已知视觉差异，不阻塞交互开发，也不计为视觉一致性通过。
