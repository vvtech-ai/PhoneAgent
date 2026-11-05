## Context

SettingsRoute当前订阅About版本和AppUpdateController并检查；AboutRoute独立读取品牌版本和日志/协议。用户批准迁移位置及业务，只取消入口右侧版本号而非取消状态文字。

## Decisions

1. AboutPage末项about-update共用现有NativeSettingCard，title版本更新、空subtitle、value默认空，仅进行中检测中，无版本号或额外箭头；isAction=true，busy时禁用。
2. AboutRoute仅Android订阅appUpdateControllerProvider，显式点击检查；异步返回需页面mounted/current、controller身份有效。沿用Controller去重和共享onChecked，不新建下载/安装逻辑。
3. 首页移除全部更新订阅/参数/动作及Web演练按钮。Web迁移预览开启时关于页末项标题显示版本更新（MOCK），右侧默认空，显式进入现有隔离更新演练页；iOS不订阅更新Controller、不显示OTA。关于页顶部真实版本展示不变。
4. 源码微批最多3文件；首页/关于测试与直接调用方分别小批更新。不改当前可信来电/国内模型等其他任务批准功能，不引用父会话旧范围进行回滚。

## Validation

OpenSpec validate --all；Flutter3.32 analyze --no-pub；设置/关于及更新模块、直接导航/工作台定向测试。重点验证末项无副标题/版本号、忙态单次、失败重试/最新提示、离页晚到和iOS无装配，以及已有更新弹层/安装链路。未改平台/依赖，不重打双端包，不真实检查网络、下载或安装。
