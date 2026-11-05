## ADDED Requirements

### Requirement: 同源启动视觉
客户端 MUST 使用参考iOS的launch_wave资源，iOS以白底居中120逻辑像素显示原生启动及Flutter登录恢复画面；Android MUST 以系统启动图标尺寸为准，在首次本地会话恢复期间保留原生启动画面。

#### Scenario: 冷启动恢复登录
- **WHEN** 应用启动并读取本地会话
- **THEN** 显示同源波形而非转圈，读取结束立即进入原有目标页面，不添加固定等待

#### Scenario: 深色模式与恢复失败
- **WHEN** 系统使用深色模式或本地会话读取失败
- **THEN** 启动画面仍为白底；读取失败保留原有错误和重试交互

#### Scenario: Android原生启动直接进入目标页
- **WHEN** Android首次恢复本地会话
- **THEN** 延迟Flutter首帧直到恢复成功或失败，保留系统启动图标尺寸并直接进入原有目标页，无额外加载画面或固定延时
- **AND** iOS及Web不延迟首帧，销毁时平衡释放，不因后续会话变更再次阻塞画面
