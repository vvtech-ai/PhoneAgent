## ADDED Requirements
### Requirement: iOS录音波形Tap必须符合当前SDK所有权接口
iOS录音波形播放器 SHALL 使用当前SDK的MTAudioProcessingTapCreate输出类型，保持成功/失败的上下文持有释放配对，不因波形适配破坏音频播放。
#### Scenario: 当前SDK构建录音播放器
- **WHEN** 使用固定Flutter工具链构建iOS Profile测试包
- **THEN** Tap创建编译通过，成功路径直接使用受管理Tap，失败路径释放上下文，正常销毁由finalize释放上下文
