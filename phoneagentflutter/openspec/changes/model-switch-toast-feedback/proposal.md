## Why
用户要求Flutter模型切换缺少Toast时补齐，与参考项目反馈一致。
## What Changes
- 首页、会话页通话模型切换及音色入口隐式切换增加成功/失败反馈。
- 国内翻译模型失败补充Toast，保留既有成功反馈和行内重试。
## Capabilities
### New Capabilities
- model-switch-feedback: 模型切换品牌提示。
## Impact
仅UI反馈，不改请求或账号边界；保留已有本地修改、不提交推送。
