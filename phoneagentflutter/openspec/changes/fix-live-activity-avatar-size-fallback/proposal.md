## Why
2026-10-29测试包1.0.54(47)日志确认：120×120头像在JPEG 0.6/0.35/0.15下分别3255/2285/1854字节，全部超过1536，客户端主动以无头像创建。用户批准增加固定像素尺寸降级。
## What Changes
- scale=1固定像素，尺寸120→80→60；每尺寸质量0.6→0.35→0.15，首个≤1536即返回。
- 用户真机确认头像恢复显示后，移除本次专用头像诊断；只保留原有可信来电运行日志。
- 保留整体4096超限直接移除头像、再次超限拒绝创建的原行为。
## Impact
PhoneAgent iOS原生管理层，owner为TrustedIdentityActivityManager；入口为现有可信来电Activity创建。eventId/attemptId和接口不变，不改下载、NSE、Flutter UI或权限。回放AVATAR-SIZE-01~04；LOG-01相邻诊断回归。
