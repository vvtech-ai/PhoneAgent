## ADDED Requirements
### Requirement: Android可信身份展示依赖必须完整打包
Android宿主 SHALL 包含参考项目Glide4.15.0运行时及编译器配置，APK守卫 SHALL 检查SDK展示字节码实际引用的关键Glide类定义，不能只确认SDK入口存在。
#### Scenario: 令牌成功后显示头像
- **WHEN** SDK获得非空身份ticket并创建身份悬浮窗
- **THEN** Glide及其SDK引用类可加载，不因缺少图片库抛出NoClassDefFoundError
#### Scenario: 展示依赖遗漏
- **WHEN** APK缺少任一已确认关键展示类
- **THEN** 打包检查失败，不将该APK记为来电展示验收通过
