# Design
TranslationSessionRoute正常terminal Navigator.pop不传成功文案，失败继续传state.error；TranslationDialerRoute将null映射空字符串。拨号号码、语言和开关保留。共享route调用方包括演练，其结果显示也不再凭空产生正常成功提示。
测试用共享完整拨号流程（320/390/430宽度）接通→挂断→返回断言无结束文案和dial-message且号码/语言/记录仍保留；保留预检失败与归档重试流程，新增对端终止场景如现有端口支持。Flutter analyze+定向flow/session/controller/返回防护，不全量回归，不重打平台包。审计仅当前翻译用户流程；原生文字未命中不等于语义不存在，台账记录具体组件接线和原生页面依据，不把独立开发演练误认正式UI。
