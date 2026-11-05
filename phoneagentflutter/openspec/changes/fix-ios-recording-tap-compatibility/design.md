# 设计

使用当前SDK管理的MTAudioProcessingTap?输出，成功直接赋值audioTapProcessor，不再takeRetainedValue。self的Unmanaged.passRetained与finalize释放继续配对，创建失败释放self。采样与播放行为不改。先真机SDK typecheck，再定向录音测试、analyze和iOS Profile测试构建；明确dev/API参数，USB保留数据安装。无真实短信、呼叫、认证；真实录音播放/波形需可用测试材料，不把编译替代验收。
