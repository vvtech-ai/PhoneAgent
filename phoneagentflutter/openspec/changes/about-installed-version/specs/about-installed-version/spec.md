## ADDED Requirements

### Requirement: 关于版本必须动态来自当前安装App
关于PhoneAgent顶部版本 MUST 动态读取当前运行包的安装元信息，Android使用versionName，iOS使用CFBundleShortVersionString。MUST NOT 展示固定、Shell演练合成、其他参考项目或服务端最新版本。

#### Scenario: 双平台及演练
- **WHEN** 用户进入正式或Shell演练关于页面
- **THEN** 读取该App自身安装版本；有非空结果显示V前缀加trim版本
- **AND** 该来源独立于Android手动/启动OTA与其隔离演练源

### Requirement: 无版本必须静默隐藏
读取中、读取失败或版本为空时，传给关于页的版本值 MUST 为""；页面 MUST 不显示版本号、占位提示、失败提示或重试入口。

#### Scenario: 等待与失败
- **WHEN** 版本尚未返回、平台不可用、异常或空白
- **THEN** 关于页不创建版本Text和专用版本间距，不显示V或默认值
- **AND** 协议/日志及底部版本更新现有契约继续有效
