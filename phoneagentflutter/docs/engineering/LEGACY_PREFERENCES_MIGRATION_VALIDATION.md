# v65 Android 偏好迁移

2026-09-20：实现与合成验证通过，真实同生产签名升级未验；不是OTA完成声明。

2026-09-21语音语言增量：[L01专项](LEGACY_VOICE_LANGUAGE_VALIDATION.md)补设备级voice_language_code，正式主ASR/备用识别同手势快照；71项相关定向（14新增）通过。它不是国外翻译语言，不改变两步初始化；真机识别和同签名升级另验。

## 2026-09-21 定位缓存补漏

固定v65的AndroidTranslationRegionRepository/DefaultTranslationRegionRepository确认：translation_region_state持久保存定位确认的国家ISO和采样时间，冷启动/定位失败读取为TrustedCache，没有新增时效判断。此前Flutter已有对应安全存储/控制器，但生产升级没有导入这份有效旧状态。

- LegacyPreferencesChannel只增加trusted_country_iso、trusted_country_sampled_at_ms两个白名单字段，不读取坐标、拨号位置猜测或权限标志。实际生产包校验保留；其他旧字段类型错误不会被本节强制转换。
- DeviceLegacyPreferences.readLocation规范化两位ISO，严格校验正整数采样时间；原采样时间不刷新。缺失整节返回null，部分缺失/非法格式明确失败，避免伪造实时位置。
- SecureTranslationLocationStore增加可选legacyRead，与显式新定位写入共用同key跨实例串行队列。新key存在（包括损坏）不回退；导入先持久再返回，失败可重试，缺失不写空缓存。没有跨进程锁或降级回写声明。
- 正式translationLocationStoreProvider复用Android非Web、prod且精确生产API门禁；现有控制器显示cached，不自动请求GPS/权限，不改变手选区号、翻译模型或初始化步骤。
- 11新增测试；51项迁移/位置存储/控制器/通道/页面相关定向通过（测试阶段约4秒），analyze5.3秒无问题，Android Debug27.3秒编译通过。未全量、未安装或读取真实私有数据；iOS原生未改，无新iOS构建。编译保留已有SDK XML版本提示，不升级工具链。

### 追加集中升级步骤

仅在获授权的同生产签名测试安装中，先用旧App正常定位留下缓存，记录国家及采样时间；完成备份和版本/签名核验后覆盖升级。首次打开国家页应显示上次可信国家，不申请权限、不自动改变区号；时间保持原值。随后显式重新获取位置、重启，保留新值不再恢复旧源。开发包和合成通道测试不能证明此真实迁移通过。

本次只关闭定位缓存这项已证实遗漏，不宣称旧状态盘点已经穷尽：旧待补偿session集合无账号归属，不能直接绑定当前账号重放；其余历史存储须继续按正式入口可达性判定，不因文件存在就迁移旧界面。

## 范围与规则

源为固定v65 `4c781e3`，原生通道只在实际包名`com.vvtech.aiassistant`读取固定白名单；Dart另要求Android非Web、prod、精确`https://chaken.ai/aiassistant-api/`作用域。

| 旧来源 | 保留字段 | Flutter目标 |
|---|---|---|
| index9_native_screen | dial_translation_enabled、dial_prompt_before_translation、dial_translation_language_mine/other、dial_country_normal/translation | SecureTranslationPreferenceStore |
| translation_call_settings | translation_overseas_provider、translation_service_region、translation_force_backend_webrtc_for_testing | SecureTranslationPreferenceStore |
| translation_call_settings | translation_play_original_audio、translation_original_audio_gain_percent、translation_original_audio_volume_percent | SecureOriginalAudioStore |
| index9_native_screen | identity_initialization_skipped | IdentityInitializationStore（设备级，非账号级） |
| translation_region_state | trusted_country_iso、trusted_country_sampled_at_ms | SecureTranslationLocationStore（国家/原采样时间，无坐标） |

中文七语言转现有语言码；OpenAi/Open_AI与UnitedStates/Japan等旧枚举转现有码；未知枚举按现有默认，错误类型报错。原音比例0–50、音量0–100，按v65取十位档。缺失部分字段使用旧默认。

新key存在时只读新值；损坏/读取错误不回退旧源。新key缺失时先映射、持久化成功再返回。读写按安全key在当前Dart isolate内跨实例串行，较后新写不会被早先导入覆盖；不宣称多进程锁。写失败保留旧源且下次可重试；无源不写默认值。三类偏好均无clear API，因此成功的新key就是导入标记。

不读取账号、号码、定位、国内provider/SIP、历史界面草稿、权限申请标志；不写不删旧文件，不回写降级数据。身份录音/本机记录迁移见各自专项文档，不由此偏好通道处理。

身份初始化补漏：v65 `AssistantContactRuntimeController`的`skipInitialIdentityForSession`及删除身份成功分支写true，重启从同一prefs读取。新通道只传存在的bool，缺失/非法类型不伪造false；Flutter无旧值保持默认，有值先持久再返回。新key包括非法字符串都优先于旧源（沿现有规则，非法字符串返回false），读取/导入失败可重试。当前显式markSkipped立即保护本实例内存选择，即使写失败也不反转，显式重试可完成持久化；旧false与新true通过跨实例队列串行。没有clear入口。此项**不启用正式初始化门禁、不决定第三步范围**，也不将跳过当作已认证。

## 自动验证

- 身份跳过补漏新增14条，含bool映射/正式provider重建门禁/目标失败/同实例及跨实例并发；身份、初始化及旧偏好共70条定向通过（测试阶段6秒）、analyze无问题、OpenSpec26项、Android Debug9.9秒。无新安装、真实数据读取或iOS构建。

- 新增12条映射/正式provider/持久化/并发/损坏与失败重试；加原音、翻译偏好及旧登录作用域回归，共34条通过（测试命令约6.5秒）。仅合成数据，无真实私有数据读取。
- flutter analyze无问题，OpenSpec22项通过；Android Debug编译11.8秒。未跑全量、未重打iOS、未安装。Android构建工作区含7个既有原生音频草稿，不是纯提交或真实升级产物。

## 集中真实升级验收（待执行）

1. 经授权，在旧生产同签名测试设备设置非默认双方语言/双模式地区、海外模型/节点、原音开关与比例/音量；记录可见值，不导出私有文件或凭据。
2. 以已核实生产applicationId、相同证书和更高versionCode升级，不卸载/清数据。`.dev`包只能验证隔离，不能证明迁移。
3. 首次进入翻译配置与设置核对所有值；退出重开应一致。修改Flutter值再重启，确认不会再次恢复旧值。
4. 检查首次无旧数据的安装、非prod及iOS行为不变；权限仍按系统实际状态。故障重试须呈现既有读取失败状态，不能静默保存默认覆盖旧值。
5. 单独验证旧登录、身份录音/本机记录与签名更新链路；本文件不能替代这些验收。旧文件未删不代表自动支持安全降级。
6. 初始化门禁正式接线后，再用已跳过初始化或已删除身份的旧安装分别升级：不应重新强制初始化；从未跳过应按原门禁判断，不自动置已认证。退出登录/换账号不得清除设备级跳过选择。不得为制造条件删除真实身份，使用受控测试安装。
