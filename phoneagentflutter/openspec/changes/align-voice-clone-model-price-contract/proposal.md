## Why
用户确认与当前aiassistant_app(a128130)声音克隆保持一致。Flutter初始化漏modelId，生成未传预期价格头，目录/准入/UI固定300；此前现场init400仍待复测。
## What Changes
- 初始化绑定所选公开modelId。
- 服务端模型pricePoints贯穿选择、认证与生成，两条生成链路带X-Expected-Clone-Price-Points。
- 认证生成幂等键使用attemptId，录音生成保持本次稳定随机ID；价格变化要求重新确认。
- 动态价格UI及安全业务错误，核对查询/试听/确认/保存/退出有效链路；保留诊断网关修正。
## Impact
Flutter双端共用voice_clone/domain/data/controller/UI及受限网络价格头。保持当前分支及其他未提交修改，不提交推送、不改后端或参考工程；不运行真实认证/音频上传/收费。
