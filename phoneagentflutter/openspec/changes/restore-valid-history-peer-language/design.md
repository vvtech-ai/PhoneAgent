# 设计

历史记录已存储 peerLanguage，无须修改存储模型。页面仅在号码成功恢复后传递历史 caller/peer 和当前模型 targetLanguages；沿用现有模型选择及空 targetLanguages 表示不限制的契约。

控制器在一次 _change 中更新当前模式国家、有效历史 caller 和重新解析的 peer。历史 peer 必须在控制器当前目录语言列表中，且符合传入模型支持集合。失效或为空时复用 _defaultPeerLanguage：所选国家目录 defaultLanguage 有效且支持时优先，否则列表首个受支持项，无可选项为空，继续由现有拨号校验阻止呼叫。不以页面当前 peer 作为回退，也不按国家硬编码语种。

保留翻译开关、另一模式国家、模型、提示和其他偏好，不自动拨号；每次同国家选择也执行。caller 的既有有效性判断不变。模型目标语种范围独立于 caller 和被叫国家，由现有 selectedTranslationModelProvider 提供，不新增模型切换。

业务微批仅控制器和页面两个文件；测试微批最多三个文件，均小于500行。验证控制器优先级、模型限制、空列表、同国重复、普通/翻译模式和持久化；页面回归 Android/iOS主题真实历史选择且不拨号。运行 analyze、定向测试、OpenSpec和diff检查，不构建或触发真实电话。
