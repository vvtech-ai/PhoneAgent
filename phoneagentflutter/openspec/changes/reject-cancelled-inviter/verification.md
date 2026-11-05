# 已注销邀请人拒绝验证记录

日期：2026-10-30。两仓分支feature/test_v1.8.0；Flutter基线3af2c3bf、SDK基线c4976045，修改前均干净。本次只修改本需求源码与回归，不提交/推送、部署、执行DDL或操作真实账号。

## 实施

- SDK新增InviteInviterLifecycleGuard及Mapper：钱包→账号锁顺序与注销一致，账号读取包含逻辑删除墓碑。在锁后取Clock核对到期未撤销的PENDING；已CANCELLED或已到期返回HTTP409、INVITER_ACCOUNT_CANCELLED及“邀请码无效”。普通缺失/非注销软删仍保留INVITE_RESPONSE_INVALID，未到期和其他活动/名额规则不变。
- 注册入口及最终提交共用Guard；最终提交在注册事务内持有账号锁，拒绝发生在创建账号、奖励之前。提交失败仍走原abort/outbox，COMMITTED重放不追溯检查邀请人。
- 仅新专用错误恢复原手机号邀请挑战，检查原有效期，不延长、不泛化到其他错误；未知失败不报告成功。
- App增加白名单与固定文案，继续由AuthController.notice→AuthRoute→NativeNotice展示Toast；保留邀请码页和有效验证，确定失败清理原注册请求ID，允许新操作。不改共用Toast视觉。
- 不新增数据库表、迁移或改变注销实现。原手写MySQL回归夹具接入真实Guard/Mapper及钱包表，以免旧测试跳过新依赖。

## 自动验证

- 新Flutter错误映射用例修改前RED（未识别专用业务码），修改后GREEN。
- Flutter3.32.0/Dart3.8.0，flutter analyze --no-pub无问题。
- 邀请模块与认证直接调用方定向回归339项通过。包括HTTP409真实Dio解码、专用码固定文案、Android/iOS实际AuthRoute共用Toast、输入页保留、验证挑战不变、更换有效邀请码成功、原失败操作ID退休。
- 显式JDK17，Maven SDK与依赖模块编译及定向测试60项通过、0失败/错误/跳过。涵盖生命周期Guard、注册入口、Snowflake事务、既有内存并发回放、挑战重试/有效期、固定验证码及登录直接调用方。
- git diff --check、改动UTF-8与两仓OpenSpec结构检查通过。

## 验证边界

未执行真实MySQL锁竞争、真实短信、名额服务联调或Android/iOS真机操作。MySQL测试夹具已同步但未运行其授权环境用例，内存并发测试不能代替MySQL证据。未打包、部署或修改运行配置；线上行为要在匹配服务端/App发布后验收。

当前PATH未发现OpenSpec CLI，因此未运行strict，仅作文件结构检查。全部源码变更保留未提交。

## 本地输出

/tmp/cancelled-inviter-red.log、/tmp/cancelled-inviter-flutter-regression.log、/tmp/cancelled-inviter-java-regression.log、/tmp/cancelled-inviter-analyze.log。
