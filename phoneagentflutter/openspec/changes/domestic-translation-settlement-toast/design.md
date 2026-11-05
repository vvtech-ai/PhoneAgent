# Design

直接读取 DomesticPointsOwner 已有 settlementUnconfirmed 标记。终态原因优先级为已有主错误、POINTS_SETTLEMENT_UNCONFIRMED、CALL_CLEANUP_UNCONFIRMED、正常结束。不能仅根据 cleanupUnconfirmed 或 finish 外层 catch 推断结算异常，因为媒体释放或结算回调异常也可能进入清理未确认状态。

translationCallFailureMessage 将专用结算码映射为用户指定正文，现有控制器和 TranslationSessionRoute 继续复用共用 Toast、根 Overlay、终态去重和返回行为。不增加页面或控件，不改变 Flutter 风格。

billing.finish、请求次数、失败重试、计费算法、资源释放、终态诊断及已确认扣分 Toast 均保持。已有明确通话错误优先，结算未确认不覆盖忙线或网络错误；仅资源清理异常保留旧兜底。

验证覆盖结算请求失败/未确认回执、主错误优先、纯清理失败、结算后展示回调失败不误分类、正常结束及双端 Theme 下 Toast 去重和跨页。协调器测试接近 500 行，拆出共用 fixture，避免超限和重复搭建；生产改动仅两个现有单职责文件且均低于 500 行。真机与真实结算验收保留待验。
