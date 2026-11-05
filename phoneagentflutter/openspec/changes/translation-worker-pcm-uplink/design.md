# 设计
原生 Android 固定参考 0f8879e4baf1d56fe6d7f8f356101fdf61d602ed 的 AssistantTranslatedUplinkPlayout 使用独立线程、160ms预缓冲、30秒上限和单调20ms节拍。本实现将16k PCM整块及完成边界送入既有UDP isolate，在同一线程取帧、可选原音混合、降采样、G.711编码和发送；不再叠加主 isolate 20ms取帧与工作线程60ms包预缓冲。默认队列继续160ms，完成短句可排空补齐尾帧。
提示音仍由既有流程提交，发送序号/时间戳由worker统一分配；DTMF同一出口处理，保持固定事件时间戳及结束重复包，暂停翻译出帧。业务原音混合算法不变，仅迁移local方向实例到worker；remote方向本地播放保持。非worker测试/适配保留原接口回退。
统计区分播放中欠载、等待模型/语句结束静音、预缓冲静音，记录输入块最大间隔与缓冲最大时长，不记录音频/号码/地址。模型等待只算idle；播放未完成耗尽算underflow。正常关闭不误报capture失败。
定向验证PCM跨块/短尾/欠载恢复/混音/DTMF、真实UDP与主线程阻塞、关闭及安全统计；两端构建，同签名保留数据安装USB手机，真实听感待用户复测。每微批最多3个源码文件，机械格式化单列；并发pubspec.lock不提交。

双端安装发现既有 iOS TrustedIdentityLiveActivity 扩展缺少 CFBundleName，MIInstallerErrorDomain 52 拒绝安装。范围内仅补标准 PRODUCT_NAME 元数据，不改可信业务/签名/权限；失败后先查询现有2026100915仍在，再重建重试，不卸载。

iOS Debug安装成功后单独启动未保持进程，最终使用测试身份的Profile/AOT包以支持脱离调试器启动，SDK仍为test，不改正式应用。Android保持debug测试包。
