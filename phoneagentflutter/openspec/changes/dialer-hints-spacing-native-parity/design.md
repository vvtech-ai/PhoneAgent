## 依据
双端topRow80/左右28；列表top24；Android空历史padding28和普通历史/联系人row上下8，iOS空historylabel top28及suggestion内容inset bottom10。iOS错误label在provider上方12，13medium红色；provider28贴dialPad，键盘至actions12，底safe32。Android配置paddingBottom10，64按键组居中；iOS有sub时main centerY-7，sub top mainbottom+2。
## 实施
按职责拆NativeDialPad；DialerPage常规高度给建议区可用空间/独立滚动，短屏大字改内容滚动保留底部actions，错误区位于配置上方，不额外展示state.name。summary视觉18+10=28，不用48布局高度撑开（按用户原生一致需求采用原生文字入口尺寸）。提示widgets提供nativeLayout用于正式host，原独立演练诊断可保留，业务状态和重试能力不改；native列表不硬截180，由页面滚动负责。联系人加载/拒绝/失败无额外常驻文本，无匹配为空；最近记录空显示原文。每微批<=3文件，均500行内。
## 验证
双平台常规/短屏/大字、键盘坐标和文字偏移、空/匹配/无匹配/权限/失败、历史回填及直接翻译流程定向，analyze/OpenSpec；无平台修改不重打包，不操作主线程设备或真实服务。真实原生配对未验不归档。
