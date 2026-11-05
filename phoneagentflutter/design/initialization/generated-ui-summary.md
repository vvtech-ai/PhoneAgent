# 初始化页面生成与验证记录

基线：Android `4c781e3`；HTML/CSS `0cd58de`。用户允许静态设计和现有组件先完成交互，视觉后校准。

- TargetAppConfig、component-tree、interaction-contract 分别记录目标配置、布局来源和3路由/3步骤/8状态/10控件/7转换边；不作为运行时页面渲染输入。
- 一个共享 InitializationPage，字段与模型卡组件，独立状态控制器；演练 route 和内存 Gateway 不进入真实 provider。真实仓库适配只复用身份/通话能力，翻译端口暂未绑定。
- 回退图标复用现有 identity_0.svg/IdentityIconButton，按钮复用 IdentityAction；真实表单/按钮/ListTile/Navigator，不用截图覆盖交互，不绘制系统栏。
- 表单可滚动、底部主按钮固定，SafeArea 处理系统区域。模型卡选中态/禁用态和失败文案有真实状态映射。
- HTML 两步视觉以 v65 三步行为补足；演练标签/退出控件属于测试附加层，生产页不需要传 previewHeader。

验证：新增15项回归、全量463项、analyze、Web/Android Debug构建、18项OpenSpec及Web验证脚本通过。浏览器正常流程、返回草稿、完成返回实测，手机宽度布局截图已检查。

未完成：生产首次入口、翻译初始化目录决策和真实偏好、跨模块刷新、双端真机、统一视觉校准；不将静态样式推导称为运行态测量。集中验收见 docs/engineering/INITIALIZATION_VALIDATION.md。
