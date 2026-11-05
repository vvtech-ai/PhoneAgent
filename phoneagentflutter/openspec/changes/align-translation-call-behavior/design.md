## 设计
以原生正式入口及领域策略为准，不按未挂载组件推断功能。目录国家绑定/模型语言权限继续有效；transport和引擎共同校验，国家只决定偏好槽和服务区域。WebRTC千问API值qwen3.5-livetranslate-flash-realtime。SIP按主被叫国家比较，实际账号沿服务器租约。
字幕使用会话独立收尾快照，终止后500ms只允许冻结keys更新，不延长音频采集；页面dispose不阻断归档，但过期账号不能写入。底层关闭时仅转发字幕，拒绝其他状态/媒体事件；结束归档冻结部分字幕为final。现有媒体先停、一次终止和录音完成保持。
时长使用非负毫秒向上取整并限制Int最大值；首次connected/translating设起点。号码提醒仅对目录有phoneRegex的纯数字输入按原生触发；用户确认后才启用3至14位纯数字兼容，不跳过国家、模型或语言门禁。确认绑定登录/号码/国家/设置快照。
每个手写业务微批最多3文件，测试/文档独立记录；定向测试覆盖策略、请求、控制器、底层收尾与页面确认；flutter analyze及openspec validate --all。真实设备/服务另列待验。

## 质量反馈接线
模型面板按国家绑定的实际transport订阅质量来源：LOCAL_SIP按精确modelId，BACKEND_WEBRTC按协议引擎；支持千问国际站诊断provider。刷新保留已有目录承载信息，避免自动退订导致重复探测；局部质量和后端质量分开读取，避免ID同名覆盖。未绑定模型显示不可用。

## 节点核验
复核8f23592的BackendTranslationCallGateway仍按plan.serviceRegion经TranslationServiceEndpointResolver解析，不采用plan.nodeEndpoint。Flutter正式通话的US/JP/其他DEFAULT及CN强制US与其一致。两端内置Local/Dev/Prod节点默认URL逐项一致；构建私有override可能覆盖默认值，未读取或变更私有参数，不声称已验证安装包运行配置。
