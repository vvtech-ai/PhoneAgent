## Why
用户确认Android SDK页面生命周期、账号退出/切换和单双卡处理严格与指定参考项目一致，替代此前Flutter额外清理/启动等待规则。
## What Changes
按0f8879e4固定源码移除SDK页面强制finish、防重复启动与25秒等待；去除SIM journal归属清理；对齐SDK先读、订阅权限或判断、null回退和SPUtil写入。MethodChannel保留传输归属检查，不控制SDK页面。
## Impact
仅Android可信宿主及专项测试，不改iOS、SDK二进制、开关或系统权限。旧journal不再读取和执行清理，不删除SDK数据。
