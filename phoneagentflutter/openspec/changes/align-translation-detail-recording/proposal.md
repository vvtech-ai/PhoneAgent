# 实时翻译详情录音与UI对齐

## Why
用户报告iPhone真实记录底部空白。业务以aiassistant_app为准，UI以AIAssistant1/android为准。已确认Flutter缺少服务端无录音时的本地副本兜底，且底部采用Column非参考的悬浮渐变布局。

## What Changes
- 以账号/环境隔离、精确serverCallId关联本地录音，服务器录音优先；无有效来源隐藏，不伪造录音。
- 归档响应保存server/client关联，失败上传保留本地映射；补充播放重试及详情可用性接线。
- 详情录音底部悬浮、渐变遮罩及字幕底部留白；沿用已有正式播放保存控件。

## Impact
translation归档与history data/provider/UI；不改后端或参考项目，不提交推送。旧数据缺精确映射不按姓名/号码猜测。iPhone已只读发现2份原始日志，无m4a，未证明对应报告记录。
