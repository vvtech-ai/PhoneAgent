# 克隆创建交互生成摘要

输入：固定HTML voiceClonePage、v65有效认证/候选结果组件、TargetAppConfig.json、ShellTokens。差量组件/状态/动作契约见clone-enrollment-contract.json。用户允许静态HTML/CSS与现有组件先行，视觉后校准。

输出：独立voice_clone feature，共7个源码文件：1 domain、1合成data端口、1controller、2页面、2组件文件；已有音色页新增明确演练入口。每文件小于500行，未改入口/原生架构。

覆盖：说明/表单/处理中/候选/完成可达，替换/退出/重录均为模态弹窗并可取消；全部本批控件绑定语义事件，无透明坐标层、无JSON运行时渲染器。未覆盖模型管理/删除/复用录音，保留后续任务。

追加管理批次：clone-management-contract.json记录分模型删除与隔离管理。复用正式模型/音色组件和控制器，独立两模型内存数据验证取消/确认/系统音色回退及另一模型保留；13新增/858全量测试通过。删除按钮暂用现有TextButton，图标与细节留统一视觉校准。身份入口创建模型选择和录音复用仍未覆盖，真实账号删除未执行。

追加创建入口批次：clone-creation-contract.json记录底部模型选择、已有克隆重认证确认、300准入、无录音/失效回认证、有效录音复用及已有候选。新增domain/entry controller/合成端口/entry route/sheet五个文件，结果继续复用原认证/候选组件；全部小于500行。已生成入口通过现有显式MOCK导航可达，正式身份页业务装配仍待真实能力接线。底部sheet/语义行/关闭与确认/取消均有事件；无坐标覆盖层、JSON运行时渲染或预览背景。系统栏仍交SafeArea，不绘制系统头尾。积分星标和箭头暂使用已有文字标签及按钮，视觉评分暂不适用，待统一校准。

组件参数来源与差异：说明padding20/gap20；表单卡padding16/gap14；结果卡padding16×18/radius18/gap12取v65，字体和颜色复用ShellTokens。结果页面外边距暂20（v65为24），试听/确认暂用现有按钮而非固定56/46高度，后续统一校准；不伪称像素级覆盖率。使用平台返回控件，无本批新业务图标/图片，不使用任何preview作背景；HTML旧假人脸框及录音图标不属于有效SDK采集页，明确排除。

系统栏/布局：Scaffold+SafeArea+滚动视口填满可用高度，不绘制状态栏或Home Indicator；Navigator push/pop、PopScope与AlertDialog负责返回/弹层，系统返回与页面按钮共享候选保护。

验证：15新增/845全量测试与analyze通过；Web和Android Debug构建通过，320/390/430宽连续Widget回归通过。浏览器从音色入口实际走到候选并检查返回提示及截图；没有新设备安装/iOS构建。高保真评分暂不适用，待批准的统一视觉校准阶段；真实平台能力不由演练代替。
