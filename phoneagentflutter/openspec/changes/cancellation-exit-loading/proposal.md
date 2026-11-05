# 注销退出连续 loading

用户2026-10-28批准：最终确认注销后在原页面保持一个无文本loading，连续覆盖申请、账号退出清理及登录页就绪；完成即撤下loading，沿用登录页中央成功轻提示。

当前HEAD 909d47409072dd19176bbd5fd391167c6ac3cd70，feature/test_v1.8.0，修改前工作区干净。源码机制：SessionNavigationHost卸载账号页面时返回无背景SizedBox.expand并等待帧确认及草稿清理，因此存在无绘制背景的过渡；未取得真机逐帧证据，不宣称现场根因已验证。

范围：PhoneAgent Flutter presentation及app接线。新增临时展示owner按账号/登录代次/操作token持有无交互页面外观；SessionController仍拥有登录及资源释放。后台API、申请/撤销及15天规则不变。保留普通退出、故障重试、账号隔离、退出前卸载及成功提示。
