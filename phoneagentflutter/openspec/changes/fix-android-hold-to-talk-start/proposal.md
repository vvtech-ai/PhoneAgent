## Why
用户反馈 Android 每次按住说话都容易漏掉开头。当前按钮使用 pointerDown 立即触发，但正式 Android 主/备用 ASR 工厂仍在识别 ready 后才开麦，握手期间没有音频。上一轮已有 iOS 有界提前采集，本轮将同一机制接入 Android。
## What Changes
Android 正式主/备用识别也在授权后提前采集，并以本轮最多2秒缓存等待识别ready；上传门禁、取消、音频独占和松手收尾不变。保留 iOS 专属 speechInput 标记及两端已有原生录音参数。
## Impact
仅正式语音工厂、实际工厂回归测试、voice-protocol delta和记录。没有长按阈值或语言迁移契约更改，不提前到用户按下/授权之前采样，不改后端、定位或供应商。
