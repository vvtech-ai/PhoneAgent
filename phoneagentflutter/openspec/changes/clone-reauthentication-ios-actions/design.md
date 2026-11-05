## Context
Flutter CloneCreationSheet._confirm使用NativeConfirmationDialog；iOS指定工程AIVoiceCloneModelFlowViewController.m showRerecordPromptExisting:使用UIAlertControllerStyleAlert，取消为Cancel，继续为Default。用户本轮明确仅按钮，优先本轮已确认目标：继续略加粗、左右等宽，不扩展重新录制/删除/退出等其他弹窗。原生代码只读，无真实身份材料作为fixture。

## Decisions
1. 增加voice_clone专属CloneReauthenticationDialog，复用现有弹窗参数及排版数值，不修改共享确认组件，避免影响其他任务。
2. 动作区零外边距、左右Expanded，横向/竖向各一物理像素分隔，17号系统蓝，继续w600/取消w400；CupertinoButton原生渐隐按压，无Material水波纹。至少48高，大字换行自然增高，保持两列。
3. 取消返回false，继续返回true，遮罩/系统返回沿用null取消；动作仅属于仍mounted/current且未完成的当前弹窗，避免重复或陈旧回调误关闭来源/覆盖页。Controller和业务端口不改。
4. 手写源码首批仅新组件与调用方2文件，测试另批。保持各文件500行内。当前共享分支codex/dev_zys，仅提交本次文件。

## Validation
flutter analyze --no-pub；双平台普通/2x窄屏短屏布局与语义、按压/取消、动作归属和克隆取消/继续连续测试，追加既有共用确认测试证明其他弹窗不变。OpenSpec validate --all。优先离线渲染图检查；本次无平台/依赖变更，不常规重打双端包或安装真实业务App，实际设备/原生像素验收单独记录。
