# 拨号联系人建议验证（2026-09-17）

## 实现与来源

固定Android v65 `4c781e3`：DialContactSuggestionPolicy、AssistantDialContactSuggestionList、DialContactDirectoryState、DeviceContactDataSource/DeviceContactPhoneCountryPolicy、ContactPinyinTokenizer、DialPhoneNumberDisplayPolicy。普通和翻译拨号使用同一规则，非Agent姓名模糊搜索。iOS复用现有CNContactStore薄端口，不引入系统通话记录。

- `dialer/domain/dial_contact_suggestion.dart`：纯数字；按contactId/缺失时name分组，姓名全拼或首字母T9前缀优先、姓名组只首号；号码子串可多个；最多10项。国际匹配去已知区号，显示保留国际区号及命中高亮。
- 来源先走共享ContactPhonePolicy：normalized国际号码优先，其次raw国际号码，国内转规范dialNumber；不能直接拿原始显示号码或后端目录key代替拨号号码。无姓名时回退有效lookup号码，不因空字符串头像崩溃。
- `dial_contacts_controller.dart`：只读已授权通讯录，requestPermission始终false；加载单飞、先清旧快照、撤权/失败清空、销毁忽略晚到；不会上传或记录通讯录。恢复前台由Host重新读取。
- `dial_contact_suggestions.dart`纯展示；Host仅适配provider/lifecycle；普通/翻译Route回调调用既有DialerController.prepare。翻译同步地区、不自动改变语言、不开通话。
- `PreviewDialContacts`只在用户主动进入拨号MOCK时启用，与实际通讯录及账号隔离。输入97看姓名，555看多号码；选择只回填。正式Web提示系统联系人不可用，仍可手动输入。

## 设计与边界

复用现有HTML/CSS拨号页，候选行取有效v65参数：36头像/12间隔/14姓名/12号码/紫色首字与蓝色命中。新头像是源组件文本圆形，不需图片；键盘/关闭/删除/拨号SVG未变。无系统栏或整页截图。普通/翻译两处均接线，无新页面路由或透明命中层。

本批列表采用最多180高度滚动、顶部12间距；源为剩余空间列表/24间距，精确高度、字体、截断和视觉差异留统一校准。不宣称高保真。新增源码均少于500行。`design/dialer/component-tree.json`与`suggestions-interaction.json`记录结构、资源、状态和事件。

## 自动与集中验收

- 纯规则：姓名优先、多号码/不同ID同名、全拼与拉丁名、10项上限、非数字禁匹配、国际区号与格式化高亮、normalized来源和空名回退。
- 控制器：静默读取、撤权清空、失败重试、单飞、销毁晚到。
- Widget：320/390/430宽度1.3倍字体；普通与翻译Route选择后显示正确姓名、号码、US地区，SystemDialer调用计数为0。
- 浏览器：正式入口→显式MOCK→97姓名候选→选择回填+1/美国/202 555 0101→清号→555显示三行与号码蓝色高亮，真实截图确认。登录保持，无验证码、真实外呼或上传。
- 最终命令：625项全量测试（新增17项）、flutter analyze与格式检查通过；Web/Android Debug构建通过；OpenSpec 19项通过。本批不宣称新iOS构建或双端安装通过，此前标准安装恢复确认尚待答复。

人工集中步骤：Android/iOS用合成测试联系人（同名不同ID、一人两号码、英文名、国际normalized号码）授权后打开拨号，输入首字母T9/号码；只能回填，不能直接拨出。后台撤权→回前台旧候选消失；重新授权后回前台恢复。检查姓名/号码不在日志或HTTP正文中。多音字/罕见字需与v65实机样本比较，lpinyin与TinyPinyin不保证逐字等价。

最近通话仍需系统与App本地翻译合并数据源、iOS仅App记录；本功能不是通话历史实现。定位、真实权限、地区持久偏好、全部Agent工具、音频/OTA与完整迁移继续待办。不能以本批标记contacts-migration整体完成。
