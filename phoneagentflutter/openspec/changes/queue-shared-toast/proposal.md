## Why
用户确认公共 Toast 按 Android 系统 Toast 的方式依次展示。当前 showNativeNotice 会立即替换上一条，导致同批初始赠送与每日登录赠送只看见最后一条。

## What Changes
- 公共提示改为 FIFO 队列，上一条淡出并移除后才展示下一条，每条独立计时。
- 保留 Flutter 公共控件的样式、文案、调用接口、默认1.8秒及积分4秒时长。
- 主动关闭清空队列；账号释放和 Overlay 销毁清理旧提示。
- 本决策覆盖 unify-branded-toast 的最新替换规则；不合并两条积分提示，不改服务端或邀请奖励确认弹窗。

## Capabilities
### New Capabilities
- shared-toast-queue: 公共 Toast 顺序展示及生命周期清理。

## Impact
公共 native_notice、SessionNavigationHost、公共提示及积分直接调用方测试。保持当前 codex/dev_zys，不切分支、仅按用户后续授权提交本批本地commit、不推送、不打包安装，不混入其他未提交修改。
