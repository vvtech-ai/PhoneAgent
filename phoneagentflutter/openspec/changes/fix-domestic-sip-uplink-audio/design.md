# 设计
固定参考iOS bb9ff349的AIClientSipMediaCodecs与Flutter算法相同，不能把相同实现互相自证。采用Python3.12 audioop作为独立G.711参考，覆盖-32768至32767全部样本；参考只生成合成输入摘要/公开音频，不使用用户语音或凭据。已读只读对照显示A-law负数896个、mu-law负数381个码字不一致，具体影响须量化，不宣称这是全部严重断续的原因。
工具通过正式PacedSipRtpTransport与WorkerPcmUplink在127.0.0.1发送公开开场，接收原始UDP并检查包头/序号/时间戳/160字节载荷，输出ignored本地证据与独立解码质量。两端共同纯Dart改动不扩展平台、依赖或权限。定向测试包含编码、重采样、RTP、worker、UDP、开场/媒体/协调器及诊断，flutter analyze；无必要不重打普通双端包。
按<=3个手写源码文件微批推进。实际电话验收独立保留，若离线不能复现严重断续，报告未定位部分，不用本地发送统计排除出站丢包。发现开场提交/发送时钟之间可复现插空时，再以有界完整PCM提交与真实发送完成确认修复；正常结束/取消/DTMF保持。

## 开场插空有效复现与修复
真实UDP专项在开场中阻塞owner180ms，固定10前静音+20有声应30包，实际39包，9帧补静音插入；未涉及网络/设备/模型。公共RTP clock正常不等于音频源连续，原voiceUnderflows只统计模型队列不能发现direct prompt插空。新增可选SipPromptUplink能力，不破坏旧SipPcmUplink假端口；完整有界prompt PCM一次送worker独立队列，最后一帧UDP发送后才确认完成，取消/错误完成等待且不重放。原Intro远端固定前/尾静音保持，非worker回退沿既有逐帧路径。Domain路由构造完整PCM，Intro等待排空与本地drain及触发边界；主媒体仅增加一个构造参数，保持<=500。worker独立prompt统计不计模型欠载，额外仅公开codec/clock/payloadType及promptFrames/directAudioFrames固定数值。三个源码微批：interface/WorkerPcmUplink/worker，transport/route/Intro，media/诊断/专项；测试另按<=3拆分。
