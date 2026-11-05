## Why
用户要求在语音模型页与音色弹层的声音克隆按钮点击时拦截无权益账号，并同步最新 App 的道歉克隆音色流程后交付测试签名包。

## What Changes
- 读取当前会员权益，明确禁止克隆时在统一入口弹取消/去升级，不先进入模型选择或认证。
- 对齐原生 App 8f23592 的道歉音色确认、候选确认（activate=false）、模型切换、拒绝停止和本次任务音色请求字段。
- 仅同步 Flutter origin/codex/dev，排除用户未授权的 dev_zys 新提交；最终推送 codex/dev 并交付登记签名 test Release。

## Impact
仅 Flutter 入口、独立道歉模块及会话接线；不部署服务，不修改数据库、默认音色或服务端 skill 文案。
