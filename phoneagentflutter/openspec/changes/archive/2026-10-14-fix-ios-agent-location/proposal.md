## Why
订餐任务在 iOS 上偶发缺少位置。当前原生通道单次定位失败或 9 秒超时直接返回空，缺少 Android 和旧版 iOS 已有的可信位置回退；共享层又可能无限沿用旧位置。首次权限请求依赖 androidPermission 字段，无法可靠处理仅有 permissionKey 的 iOS 请求。
## What Changes
修复 iOS 定位采样、短暂错误重试和有时效/精度限制的回退；限制共享层旧位置作为请求上下文的有效期；权限申请依据已校验的跨平台 permissionKey。权限未授权时不上报缓存坐标。
## Impact
仅客户端定位与权限编排、回归测试及记录。参考旧 iOS iOS/pro/v1.0.46 0c652847 的 AILocationService 和当前 Android。保留现有通道及后端协议、账号隔离和开发环境。不改后端、不进行下单或外呼。
