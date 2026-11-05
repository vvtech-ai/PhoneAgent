## 设计
复用DiagnosticEvent/Journal和既有日志上传。新增封闭枚举详情，endpoint采用静态别名而非实际路径，模型/认证/候选/用户ID不进入日志。AccountApi只在命中克隆白名单路径时附加诊断，记录HTTP及白名单业务分类；X-Reqid仅接受UUID用于后端对照，不添加或改变请求头。
SDK日志在Dart通道及已有端口边界记录，不修改原生SDK、不额外采集权限或设备资料。端口装饰器使用本次流程随机UUID串联操作，保留原异常、返回对象、调用次数和取消/释放语义；未知响应不记录正文。认证解码只记录字段名与JSON类型。
状态日志记录枚举状态/问题及轮询序号；日志sink故障隔离。流程退出、账号变化、可选录音后台保存保持原生命周期。手写微批不超过3文件；超过500行先拆职责。

## 验证
定向日志序列、脱敏、HTTP400/业务200失败、响应格式、SDK异常/取消/释放、轮询失败/上限、生成/确认/试听/录音异常和sink故障测试；现有clone/直接调用方及公共AccountApi/Journal回归、flutter analyze、openspec validate --all与diff检查。无平台/依赖变化不重打包。真机新日志上传与真实服务错误复现待验。

## diagnostics-11现场补充
现场只有流程日志而无voiceCloneRequest，确认网关前缀未归一化：当前SDK构建base含/aiassistant-sdk-api/。通过ServiceRoutes按已配置base剥离前缀取得逻辑路径，再执行精确白名单匹配，不用任意子串截断、不记录原URL。新增真实前缀下AccountApi集成回归，含400白名单/未知错误、200业务拒绝、超时和401刷新；签名仍使用完整URL不变。
补初始化modelId是否存在的布尔元数据及缺失模型/签名错误固定分类，不记录模型ID或请求正文。当前Android6b9aa34引入初始化modelId，现Flutter漏参；当前Android另有动态价格/预期价格头差异。这些业务变更单独列为已确认源码差异，本轮日志补丁不静默改认证/计费。

## 试听诊断补充
系统/克隆音色sheet和克隆流程共用播放器均注入当前账户journal。每播放器随机UUID关联input/source/prepare/playback/event/dispose/sourceCleanup/stop；仅检查容器标识和WAV fmt/data结构，不存音频字节、路径、URL或原始异常。平台异常只允许固定code/domain和数值NSError码，未知值归other。日志故障隔离，保留原清理顺序和异常传播。验证定向播放器、脱敏和导出往返测试，analyze/OpenSpec；不安装或触发真实认证。
