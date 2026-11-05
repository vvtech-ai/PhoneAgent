## Why
用户反馈iOS实时翻译接通后停止通话App闪退。USB设备2026101006在2026-10-10 12:09:43的原生ips确认SIGABRT，异常栈PcmOutputChannel.release→AVAudioEngine.detachNode→Graph.RemoveNode。共享duplex引擎仍运行时拆播放节点；Swift do/catch不能作为ObjC异常防护。真实崩溃文件仅/tmp保留，不提交。
## What Changes
- 播放停止/节点拆除前停止引擎，显式断开输出、清除attached事实，保留采集tap/所有权供格式切换下一输出重启。
- 用实际release函数的隔离Swift替身回归运行图不变量、重复停止/失败重试及非duplex行为；验证Flutter清理调用方和iOS构建。
## Impact
仅iOS PCM释放，无Android/网络/积分/SIP策略变更；不新增权限，不自动真实拨号。已解决的上行音质继续保留。
