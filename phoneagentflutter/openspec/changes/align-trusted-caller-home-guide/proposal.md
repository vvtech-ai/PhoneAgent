## Why
用户确认执行可信来电差异修复：首页引导仅Android，功能/交互对齐aiassistant_app，Flutter样式及公共控件保留，必要UI参考AIAssistant1；iOS保持无首页引导并核验自动推送绑定。

## What Changes
- 修复Android test Release `.test`与Dart SDK环境不一致，统一启动和通道映射。
- 增加Android一次性首页引导、关闭后二次提醒及不再提示，展示记录不作为授权证明。
- 首页与设置复用SDK入口；Android调用完成代表发出启动，取消误称退出后完成及立即状态刷新；iOS保持退出后完成。
- 核验iOS恢复登录/新登录、token先后顺序、权限及账号变化；不主动重复权限请求。

## Impact
仅PhoneAgent可信模块及Shell接线、定向测试。SDK二进制、SIM保留、系统开关和iOS设置导航不变。不切分支、不提交推送、不打包安装、不触发真实认证/来电。
