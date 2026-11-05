import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/features/conversation/presentation/pages/permission_preview_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/voice_input_preview_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/batch_flow_preview_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/receipt_preview_page.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_flow_preview_page.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_permission_preview_page.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_cleanup_preview_page.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_preview_scenarios_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/app_call_records_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/audio_focus_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/agent_context_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/agent_location_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/voice_transport_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_access_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_location_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/livekit_translation_preview_page.dart';
import 'package:phone_agent/features/app_update/presentation/pages/startup_update_preview_page.dart';
import 'translation_call_preview_launcher.dart';
import 'auth_preview.dart';
import 'conversation_preview.dart';
import 'shell_preview.dart';
import 'feedback_preview.dart';
import 'points_session_preview.dart';
import 'agent_document_preview_page.dart';

class WorkbenchScene {
  const WorkbenchScene(
    this.id,
    this.group,
    this.title,
    this.boundary,
    this.build,
  );
  final String id, group, title, boundary;
  final WidgetBuilder build;
}

/// Reuse shared hosts with isolated synthetic ports. Any unsupported API must
/// fail closed with unconfigured endpoints, never fall back to a real account.
final workbenchScenes = <WorkbenchScene>[
  WorkbenchScene(
    'agent-document',
    '登录与对话',
    'Agent索要文档与取消续接',
    '正式共享弹层/控制器；成功、取消、失败和超限均为合成端口，不读文件或访问真实账号',
    (_) => const AgentDocumentPreviewPage(),
  ),
  WorkbenchScene(
    'initialization-app',
    '基础 App 连续导航',
    '首次初始化→首页',
    '正式登录后两步：身份→通话模型；仅合成身份与内存跳过，初始化不设置翻译模型、不发短信或电话',
    (_) => const ShellPreviewPage(initializeIdentity: true),
  ),
  WorkbenchScene(
    'task-error-recovery',
    '基础 App 连续导航',
    '异常退出与恢复',
    '正式对话/任务页；外层模拟断网，退出后恢复网络再从任务续聊；状态请求只进内存，不操作真实网络或账号',
    (_) => const ShellPreviewPage(errorControls: true),
  ),
  WorkbenchScene(
    'app',
    '基础 App 连续导航',
    '首页→模型→任务→设置→积分→翻译',
    '正式共享路由、合成账号/积分/翻译/身份克隆；新对话可在任务列表恢复，退出登录或场景后重置。验证码1234；认证、录音、位置和媒体仅模拟，其他未接接口明确失败',
    (_) => const ShellPreviewPage(),
  ),
  WorkbenchScene(
    'auth',
    '登录与对话',
    '登录与邀请码',
    '合成短信/邀请码/内存登录；含保存失败和恢复重试',
    (_) => const AuthPreviewPage(),
  ),
  WorkbenchScene(
    'conversation',
    '登录与对话',
    '统一对话与回执组件',
    '确认卡/单路/批量文本样例；输入仅在内存，不代表 Agent 响应',
    (_) => const ConversationSamplesPage(),
  ),
  WorkbenchScene(
    'permission',
    '登录与对话',
    '文字对话与权限工具',
    '共享对话控制器；权限结果和后端均模拟',
    (_) => const PermissionPreviewPage(),
  ),
  WorkbenchScene(
    'voice',
    '登录与对话',
    '按住说话与文字切换',
    '默认语音、草稿/失败恢复；不采集真实声音',
    (_) => const VoiceInputPreviewPage(),
  ),
  WorkbenchScene(
    'batch',
    '任务与通话',
    '批量任务与回执',
    '合成事件推进共享页面；无真实多路外呼',
    (_) => const BatchFlowPreviewPage(),
  ),
  WorkbenchScene(
    'single-call',
    '任务与通话',
    '单路通话与结果播报',
    '共享单路状态/返回/播报；电话和声音均模拟',
    (_) => const CallFlowScenariosPage(),
  ),
  WorkbenchScene(
    'recording',
    '任务与通话',
    '回执与录音',
    '合成录音/失败重试；不下载或播放用户音频',
    (_) => const ReceiptPreviewPage(),
  ),
  WorkbenchScene(
    'call-records',
    '任务与通话',
    'App 本机通话记录',
    '隔离内存记录；不读取或删除系统历史',
    (_) => const AppCallRecordsPreviewPage(),
  ),
  WorkbenchScene(
    'translation',
    '国外翻译',
    '配置→通话→结束归档',
    '模拟位置/目录/服务/媒体/归档；开启配置到通话开关走完整演练',
    (_) => const TranslationAccessPreviewPage(),
  ),
  WorkbenchScene(
    'translation-call',
    '国外翻译',
    '翻译通话演练（MOCK）',
    '正常双语/环境检测失败/挂断失败重试；不使用拨号号码，不连接真实电话或媒体',
    (_) => const TranslationCallPreviewLauncher(),
  ),
  WorkbenchScene(
    'translation-session',
    '国外翻译',
    '通话与失败回退',
    '共享会话协议状态；未连接真实 LiveKit 或电话',
    (_) => const TranslationSessionPreviewPage(),
  ),
  WorkbenchScene(
    'translation-location',
    '国外翻译',
    '当前位置与国家选择',
    '合成定位/权限/缓存；手选区号不冒充真实位置',
    (_) => const TranslationLocationPreviewPage(),
  ),
  WorkbenchScene(
    'livekit',
    '国外翻译',
    'LiveKit / AppAudio 状态',
    '共享适配器加合成房间/PCM；不证明真实声音质量',
    (_) => const LiveKitTranslationPreviewPage(),
  ),
  WorkbenchScene(
    'feedback',
    '评价与积分',
    '赞踩与条件评分',
    '合成评价/内存草稿；首提交故意失败，可重试和查看只读结果，不写真实评价或发积分',
    (_) => const FeedbackPreviewPage(),
  ),
  WorkbenchScene(
    'points-session',
    '评价与积分',
    '积分激活与会话恢复',
    '合成账号/余额/赠送；重挂载不重复激活，退出场景重置，不访问真实积分',
    (_) => const PointsSessionPreviewPage(),
  ),
  WorkbenchScene(
    'identity',
    '身份与设置',
    '身份删除与本地清理',
    '身份/关联存储为模拟；不删除真实用户资料',
    (_) => const IdentityCleanupPreviewPage(),
  ),
  WorkbenchScene(
    'clone',
    '身份与设置',
    '声音克隆完整交互',
    '创建/核验/录音/管理场景；SDK、音频、余额均合成',
    (_) => const ClonePreviewScenariosPage(),
  ),
  WorkbenchScene(
    'developer',
    '身份与设置',
    '开发者及初始化场景',
    '原有隔离演练集合；初始化为身份与通话模型两步，正式入口连续流程见首次初始化→首页',
    (_) => const DeveloperPreviewPage(),
  ),
  WorkbenchScene(
    'ota',
    '身份与设置',
    'Android 启动与更新',
    '模拟版本/下载/安装；iOS 正式无 OTA，不安装真实包',
    (_) => const ProviderScope(child: StartupUpdateScenariosPage()),
  ),
  WorkbenchScene(
    'dial-permission',
    '系统能力（模拟）',
    '拨号权限顺序',
    '合成授权/拒绝/设置返回；不改变系统权限',
    (_) => const DialPermissionPreviewPage(),
  ),
  WorkbenchScene(
    'audio-focus',
    '系统能力（模拟）',
    '跨模块音频占用',
    '仅资源状态演练；真机路由/打断待集中验收',
    (_) => const AudioFocusPreviewPage(),
  ),
  WorkbenchScene(
    'agent-context',
    '系统能力（模拟）',
    '对话时间与权限上下文',
    '合成时间/权限，不采集真实设备信息',
    (_) => const AgentContextPreviewPage(),
  ),
  WorkbenchScene(
    'agent-location',
    '系统能力（模拟）',
    '对话位置上下文',
    '合成位置和共享状态；不申请定位',
    (_) => const AgentLocationPreviewPage(),
  ),
  WorkbenchScene(
    'voice-transport',
    '系统能力（模拟）',
    '语音网关状态',
    '合成协议/传输，无真实网关或麦克风',
    (_) => const VoiceTransportPreviewPage(),
  ),
];
