## 设计
在HttpTranslationBackendRepository的_post边界替换x-user-id为mobile-app-user，create/merchant/hangup及清理/兼容请求一致。请求模型userId、runtime accountId、登录有效性检查、finished recorder及归档身份保持真实账号。无账号仍拒绝内部调用。每次HTTP操作记录固定NATIVE_SERVICE_USER类别，不输出账号值；沿用操作阶段以便对应请求。保留caps一次兼容和cleanup。
## 验证
backend三个操作及兼容请求headers、runtime账号归属/失效、归档记录和session页面定向；analyze/OpenSpec。源码2文件微批，测试2文件独立微批，无500行例外。不实际外呼、不安装、不提交推送。
