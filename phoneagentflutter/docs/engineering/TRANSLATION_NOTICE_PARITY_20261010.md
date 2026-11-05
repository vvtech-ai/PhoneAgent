# 实时翻译提示差异盘点（2026-10-10）

范围：正式翻译拨号、预检、共享通话及返回、模型弹层、海外设置；不是全App提示审计。Flutter以1c2fa19b后本批修改为准；固定原生Android 0f8879e4、iOS bb9ff349，只读git show/grep核对。文字未命中不单独当作业务不存在，以下区分位置/方式差异和文案差异。本次没有真机UI截图或呼叫。

## 本批已对齐

正常终态不传回“通话已结束”，拨号页空结果清除notice；失败仍保留state.error。修改TranslationSessionRoute与TranslationDialerRoute，号码/语言/记录/归档/清理不变。iOS AIMainTabBarController.m:6667终态处理国内等结算回调后返回、不展示账单，海外返回；Android TranslationCallScreen.kt:61按terminalPresentation国内结算页完成退出、海外自动DismissTerminal，Coordinator:139重置Idle。两者拨号页无此正常结束常驻提示。原生通话状态的同文案不作为拨号页存在依据。本批不更改Android国内结算与iOS直接返回的既有平台差异。

## 其他额外展示（尚未修改）

| 场景/Flutter组件 | 文案或展示 | 对照结论及建议 |
|---|---|---|
| 拨号页 TranslationRecordSaveStatus | 正在保存本机翻译记录；本机翻译通话记录保存失败，可重试 | 两参照翻译拨号/终态流程未找到同位置本机持久化状态或重试按钮。正常保存进度属于内部过程，宜静默；失败恢复应设计统一承接位置，不能直接删除保存/重试业务。 |
| 拨号页 TranslationArchiveStatusView | 正在同步翻译历史；翻译历史同步未完成，点击重试 | 两参照未找到对应拨号页归档状态/重试入口，属于Flutter增加的恢复展示。宜将后台归档进度静默，失败恢复移到记录/历史等业务位置，需单独定义，不应直接丢弃pending。 |
| 拨号页及海外设置 TranslationStorageStatus | 正在读取/保存翻译配置；配置已保存在当前环境，将用于新发起的翻译通话；重试读取/保存 | 海外设置两参照展示模型/节点选择及后续通话说明，未接入Flutter式环境持久化状态面板。拨号页仅loading/saving/error时接入，成功长说明不会常驻拨号页；海外设置无条件接入，成功说明会显示。正常读写状态宜静默，失败应保留简洁业务反馈和可恢复动作。 |
| 海外设置 TranslationCatalogStatus | 正在读取所选节点支持的语言；节点支持N种语言/列表；目录查询成功不代表模型、音频或电话已就绪；语言目录失败/重试 | 实际由TranslationSettingsRoute传serviceStatusBuilder并在TranslationSettingsPage插入。Android OverseasTranslationSettingsPage、iOS AISettingsOverseasTranslationViewController模型/区域页面无此目录查询卡片。尤其“查询成功不代表就绪”为工程说明，宜移出普通设置页；目录功能不因隐藏卡片而自动删除。 |
| 海外模型弹层 translation_model_sheet.dart | 计费倍率暂未获取，不显示估算值；重试倍率 | 两参照未找到同文案；计费倍率获取/失败本身是有效业务，仅文字搜索不足以排除原生同义反馈。标记文案/呈现待核对，不自动移除价格失败提示。 |
| 不满足海外入口时 TranslationSettingsRoute/translationAccessMessage | 当前位置为中国；国内 SIP 翻译暂不迁移；强制海外已开启等 | 中国分支“暂不迁移”已过时，与国内SIP已实现矛盾；通过入口守卫通常不进入此页，但动态位置改变时fallback可呈现。原生同位置未找到该迁移阶段说明。应修正业务文案；强制海外/位置未确认保留功能含义，不按工程字样一刀切删除。 |
| 无会话binding时拨号页 | 当前环境无法发起实时翻译通话，请在已登录的手机 App 中使用 | Flutter多环境/演练端口边界提示，原生无相同跨环境说明。一般非正常已登录手机路径；需区分正式端口配置失效与演练，不应直接移除禁止外呼门禁。 |

## 有原生依据，不能当额外提示删除

- 请输入正确的电话号码：双端PhoneNumberPolicy有相同文案。
- 麦克风权限未开启，无法发起实时翻译通话：iOS拨号预检errorLabel有同文案；Android也有权限准入流程，表现可能不同。
- 实时翻译通话预检失败：iOS预检失败使用底部toast约2.5秒；Flutter当前持续页面文字，属于展示方式差异，不是没有原生依据。
- 位置待确认：双端模型标题/准入有对应状态。
- 翻译通话模型已切换为…：双端模型切换回调有明确toast，不能因新提示排查而删掉。
- 只影响之后新发起的海外实时翻译通话、选择离你更合适的翻译服务节点，只影响后续通话：双端海外设置均存在。
- 失败终态返拨号页持续错误：本批保留；原生可能在通话页或toast呈现，需要逐错误生命周期核对，不能将正常结束清空规则套到失败。

## 演练边界

独立preview页面的MOCK、合成流程、注入按钮不计入正式产品额外提示；但实际正式接线的上述status组件已纳入。本次未断言整个App不存在其他不一致提示，也未对所有异常toast持续时间做设备测量。

## 验证

三个宽度完整拨号→接通→挂断→返回回归在修改前均RED（仍有结束文字），修改后预期无结束文案/无dial-message并保留号码、语言、记录。另验证预检失败、归档重试、共享会话对端结束/异常返回、设置/拨号覆盖和销毁防护。具体结果见根tasks.md与codex_issue_log；首次定向命令误列不存在的translation_session_route_test.dart，读取文件清单后改实际translation_session_pages_test.dart复验，不将该失败报为业务回归。
