# 设计

扩展 AppEnvironment 枚举；解析复用所有地址校验，test 不自动映射为 dev，也不改变 Release 门禁。
已有可信来电以 prod/pro 与非生产/test 分流，不增加重复分支。翻译区域历史默认保持不变，显式 TRANSLATION_* 优先。仅 dev 的本地 Web 代理保持 dev 专属。
测试构建分别读取 .local/cloud-test/device-defines.json 与 ios-device-defines.json，检查 APP_ENV=test、三个 chakenai-test HTTPS 服务及四项签名凭据。
验证环境解析、独立服务路由、危险 URL 拒绝、Release 拒绝、非生产翻译及可信来电行为；双端保留数据覆盖安装、版本与启动分别验收。
现有开发包和测试包共用非生产身份，覆盖安装保留存储；账号可能因服务端环境切换需要重登，不承诺旧令牌在新环境有效。
