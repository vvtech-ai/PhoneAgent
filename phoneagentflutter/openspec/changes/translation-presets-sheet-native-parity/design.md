# 设计
原生依据Android TranslationPresetsSheet.kt与iOS AIMainTabBarController.m AITranslationDialSettingsViewController：最大460、背景FCFCFD、顶部24圆角、遮罩52000000、18顶/20侧/28底；标题19bold、44关闭20图标；行间14，语言标签13semibold独立、下7、双卡间10，卡片14圆角/边DCE4EF/底F8FAFD、左右13、箭头18，iOS46高、Android上下14；呼叫按钮54/圆角18/上18及原渐变。Android开关48容器内34×20白thumb/绿色track；iOS直接34×20、14高track。iOS淡入300ms、Android无进出位移动画，无拖动把手。短屏/大字可滚动，正常字号紧凑。
抽离options控件及紧凑开关，preset owner保留状态与确认守卫。使用generalDialog同navigator，语言push返回保留弹窗。移除route传入额外海外设置入口，保留独立设置页面。源码每批<=3，均<=500行；定向覆盖双平台开关/语言/取消/确认与权限直接调用，analyze/OpenSpec，不构建安装真实外呼。


2026-10-09用户确认纠正：移除擅自添加的设置首页“海外模型与服务区域”卡片、枚举、显示参数及首页跳转/依赖；不迁移到其他页面，不删除海外配置页面、Controller、持久化及拨号能力。此前“迁至设置首页”的方案撤销，不能作为产品授权依据。
