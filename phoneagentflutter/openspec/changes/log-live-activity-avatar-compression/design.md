> 历史排查记录：2026-10-29用户已确认头像恢复显示，并要求移除本次专用调试日志；下文为此前诊断阶段记录，当前实现以fix-live-activity-avatar-size-fallback为准。

## Owner与范围
基线9865a149，当前工作区干净。状态owner为TrustedIdentityActivityManager当前事件与generation。新增每次admit后的attempt UUID，同事件重试可区分；事件UUID不使用姓名/号码。入口为既有verified/uncertified来电的Live Activity公开请求，不改API、请求身份或系统权限。原生投影与Dart双层白名单，限定stage/code、枚举、数值范围、UUID和版本格式。
## 不变量
默认renderer scale、40×40点、三档JPEG、1536字节、32KB输入、4096字节整体限制及调用顺序不变；未知/失败依旧回退，不新增图片请求或编码尝试。只记录已有结果和编码长度，不输出图片、URL、身份正文、凭证或异常原文。日志不依赖认证/crash模块，不安装处理器或修改音频。沿用消费者/账号归属及64条有界缓冲。
## 事件
单一IOS_ACTIVITY_AVATAR码，phase=input/render/attempt/selection/budget/request，reason为固定枚举。记录输入bytes/尺寸、实际scale×1000和输出pixels、实际质量字符串、JPEG bytes、budget编码与移除后的bytes、最终携图布尔。每个尝试记录App真实版本/build和OS版本；不把Dart构建参数当安装版本。
## 验证
先以失败回归证明新字段尚被过滤，再native白名单/序列化/隐私/owner测试，Swift分支日志和原算法不变回归，Flutter定向与analyze、Mac iOS编译和匹配符号。设备实测需已安装同构建与真实推送条件；无此证据保留待验，不以单测或模拟代替，不自动安装/外呼。
