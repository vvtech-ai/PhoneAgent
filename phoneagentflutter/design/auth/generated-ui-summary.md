# Auth UI 交付范围

输入：0cd58de9 HTML runtime 24 节点、NormalizedDesignTree、component-tree 和 7 条 InteractionMap；行为以 v65 4c781e3 为准。只交付登录/邀请码展示与状态模块，不代表认证服务已接入。

## 结构与覆盖

- app/phone_agent_app：主题和 go_router 根入口；main.dart 无页面逻辑。
- core/design/auth_tokens：测量尺寸、颜色、文字和背景。
- features/auth/presentation：AuthRoute 依赖组装，AuthPage 输入编辑与渲染，AuthFrame/Brand/InputGroup/PrimaryButton 语义组件，AuthController 业务状态编排。
- features/auth/domain：纯 Dart 契约/手机号与验证码规则；data：明确不可用适配。测试替身仅在测试目录。
- 24/24 视觉源节点被映射到语义布局（包含容器，不是24个独立 Widget 类）；7/7 关键交互直接绑定真实控件；2/2 页面可达。
- 1/1 Logo 真实资源，PNG 原图 contain，SHA256 校验。无整页 preview 背景、无 JSON runtime renderer、无透明点击层；preview 仅供对照。

## 参数级视觉契约

设计内容 viewport 390×793；来自390×844原型扣除顶部41和壳底10。运行时填满平台区域，不硬编码793。

| 类别 | 源及参数 | 验证/差异 |
|---|---|---|
| 品牌/图片 | auth-brand-logo 107×97.97，contain，底距14 | Flutter107×98；真实 Logo，非裁切、无 mask；Widget 尺寸断言 |
| 标题 | auth-logo 28/800，字距-0.5，高37 | token一致；系统字形与 HTML Windows 字体略有差别，用户允许平台差异 |
| 副标题 | auth-subtitle 14，高19，#8B8FA3，顶距6 | token一致，长字/大字允许换行 |
| 表单布局 | auth-form max320；390宽时 x42,w306；品牌内容至表单54 | Widget断言x42/w306，设备大屏采用320上限，不按截图整体缩放 |
| 输入 | auth-input-group h58,r12,#F5F7FA；两行gap12；输入15/20，内边距14/18 | 实测参数对应；focus边框#0A84FF；小屏/大字验证码操作纵向排列，避免挤压 |
| CTA | loginBtn 高49,r12,#0A84FF；距字段20；16/700 | Widget断言49，top567.984±2；两页截图可见，禁用opacity .45 |
| 返回登录 | HTML未画；v65 V88AuthPages.onBackLogin | 按当前代码补齐，故邀请码内容总高/位置不与HTML逐像素相等 |
| 系统/背景 | .screen两层浅色渐变；.status-bar排除 | SafeArea与自适应背景；不绘制9:41、不复制系统底部留白 |

不适用：BottomNavigation、列表、详情动作、FAB、业务弹窗、遮罩，本批设计中均无。

## 状态与限制

邀请码仅后端结果驱动；默认未接入适配不返回该结果。合成集成测试覆盖两页、发送冷却、邀请码错误以及返回，不能视为真实认证通过。真实 HTTP/会话持久化、首页、iOS 页面验证留后续。手写 Dart 最大文件低于500行，自动架构测试已通过。

结论：允许进入本批自动验收/里程碑，不允许宣称登录业务或双端全量验收完成。
