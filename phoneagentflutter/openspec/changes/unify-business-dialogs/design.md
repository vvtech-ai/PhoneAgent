## Decisions
NativeBusinessDialog负责共用视觉；NativeConfirmationDialog保留bool返回适配。卡片白底、圆角22、横向外边距34、内边距20/22、标题21/w800居中、说明13/18居中、18间距及NativeGradientAction等宽按钮/10间隔。说明授权默认蓝色，危险确认红色。支持单按钮、业务content/error、滚动、disabled和allowBack；业务包装组件保留各自生命周期。
联系人双端统一允许访问通讯录/暂不/继续授权，删除深色AI图标和旧分支；系统UI/转场适配保留。更新内容与状态继续展示，force隐藏取消且原PopScope保留。底部评价成功Dialog按视觉属于Sheet，明确排除。
## Migration
1 共用组件/确认适配/退出；2记忆/恢复默认/权限；3身份/克隆；4网络/奖励/通话；5更新及演练遗漏。每个手写源码微批不超过3文件，测试和记录独立批次。无人使用的纯样式组件删除，仍承载业务配置/状态的适配保留。
## Validation
按模块运行定向Flutter测试和analyze，更新因跨模块公共弹窗触发一次交付回归（不默认全App重复回归），覆盖小屏大字体/长内容/单按钮/禁退/旧路由。OpenSpec/diff校验；设备视觉待验不归档。
