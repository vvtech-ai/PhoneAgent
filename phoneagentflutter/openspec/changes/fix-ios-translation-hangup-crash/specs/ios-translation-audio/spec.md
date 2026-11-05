## ADDED Requirements
### Requirement: iOS翻译音频图必须安全拆除
iOS翻译通话 SHALL 在拆除播放节点前停止共享音频引擎并断开节点输出，SHALL 清除挂载事实以支持重复停止及session释放失败重试；SHALL NOT 依赖Swift捕获ObjC异常来保证不崩溃。
#### Scenario: 接通后挂断
- **WHEN** 播放与采集共享引擎且通话结束
- **THEN** 播放节点在引擎停止后拆除，采集和会话所有权按既有流程释放，不重复拆除节点
#### Scenario: 播放格式切换
- **WHEN** 旧输出关闭后创建新采样率输出
- **THEN** 保留采集tap与通话所有权，新输出启动共享引擎，不创建额外采集会话
#### Scenario: 会话释放失败重试
- **WHEN** 节点已经拆除但session清理失败
- **THEN** 保留失败事实并允许重试，不重新拆除旧节点
