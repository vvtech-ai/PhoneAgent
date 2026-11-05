# v67邀请展示复查与修正

来源只读：旧项目 `origin/test/v67.0.0` 冻结 `5c0d737dc0a4c809cabafce2dfe9c8c0be4ba3a3`，当前原生App `feature/test_v1.6.0` 为 `1e67c2d`。本批不运行Flutter/analyze、不构建安装，不发送邀请或确认真实奖励；主线程统一验证。

## 来源依据与职责

`InviteHomeScreen.kt` 的刷新条顶部12dp、错误Row顶部10dp；`InviteRecordsScreen.kt` 的错误Column上下18dp、加载更多顶部6dp。首次失败直接放在表头分割线之后，只有初次加载和空记录用剩余区域居中。

`invite_activity_card.dart` 与 `invite_records_page.dart` 只负责上述展示参数，未改controller、API、权限、分页事实和奖励确认。共享标题和大字邀请位最小宽度保持现状，首页礼物/设置入口、总积分直达原流水与内部积分分类规则不变。

## 已保存证据的实际限制

已查看1208真机邀请、记录空态与纯积分流水截图；已查看默认390宽合成福利、非空记录、奖励图及v67 HTML Demo。没有同账号同数据的原生截图，不能声称像素一致。旧邀请码错误截图是修复前状态，仅参考错误布局。HTML旧余额与邀请混页不能反向覆盖已确认独立入口。

旧视觉测试只在1×时写PNG，2×无异常断言不能证明阅读体验。现测试保存375/390/430宽的1×与2×截图（默认文件名兼容，2×追加`-2x`），追加活动刷新/失败、记录加载/空态/首次失败/翻页失败场景。加载态采用有限pump，避免无限进度动画导致pumpAndSettle超时。流水合成说明使用业务名称，不展示来源余额分项。

新增首次失败位置与重试事件定向用例；该用例在修改前已写入，但按主线程禁止运行要求未观察RED，不宣称完成TDD循环或通过。

## 待主线程执行

- `test/features/invite/v67_invite_pages_test.dart`：首错位置、重试和既有入口/两列记录。
- `test/features/invite/v67_invite_visual_test.dart`：12场景×3宽×2字号，72张合成图；需沿用已配置字体及COMMERCE_CAPTURE_DIR。
- `test/features/invite/v67_invite_reward_test.dart`、`test/features/points/v67_points_ledger_test.dart`：奖励与原流水已有行为。
- analyze、OpenSpec校验由主线程统一运行；本批仅检查diff与UTF-8中文。

绘图后只读检查奖励、邀请与流水2×截图。奖励仅在可见问题确认后修改自身组件，不先凭源码改共享字号或压缩邀请位。合成图与真实设备截图必须分开描述。

## 2×奖励遮挡修复

主线程绘制的`ui-recheck/v67-reward-375-2x.png`与`-390-2x.png`明确出现“已存入你的积分账户”压在“+300积分”上，默认字号图正常。原卡片固定金额top241、说明top329，字体随2×增高导致碰撞，横向FittedBox不能保护纵向间距。

已在`v67_invite_reward_test.dart`增加320/375/390/430宽1×/2×实际绘制矩形回归，用RenderBox变换处理FittedBox，校验标题、金额与积分单位、说明、按钮纵向分离。主线程实际观察旧源码RED：5通过、4失败，四个2×宽度金额与说明重叠；日志`D:/Temp/story1837-reward-ui-red.log`。本agent未运行Flutter。

奖励卡自身增加大字纵向内容布局，金额与单位允许换行，账户说明与按钮依次排开且卡片随内容增高，字体仍由系统缩放。默认544×518构图分支不变，绿色图案、颜色与确认事件保持；未改共享标题、海报、邀请位或奖励确认状态。GREEN与重新绘图待主线程统一执行，不以源码修复代替视觉验收。

## 本批最终验证

主线程已运行奖励矩形GREEN、邀请间距与视觉/流水等定向集合，组合定向291项通过，analyze无问题、OpenSpec94项通过（集合有重叠，不相加；详见COMMERCE_UI_RECHECK_20261013）。本agent独立看了重新绘制的`v67-reward-375-2x.png`，标题、金额、积分单位、账户说明与确认按钮已纵向分离，没有此前遮挡；默认构图截图不变。奖励仍是合成组件证据，未触发真实奖励或已读确认。

最终测试APK2026101302同签名保留数据覆盖Success，首次安装2026-10-10 12:36:18不变，登录首页与总余额8989保留。新真实截图`android-1302-welfare.png`、`-invite.png`、`-invite-records.png`确认首页礼物/设置邀请双入口、0/2空记录、可用未邀请位与正常按钮、来源返回；`-ledger.png`保留纯列表、时间/说明/操作后余额，未展示来源余额分类。只读HTTP证据邀请activity/code/records为200与000000，目录/current/orders仍404且可重试，支付禁用；不能称会员、发票、后台部署成功。最终停留普通首页，无短信、外呼、购买、实际分享或奖励确认。设备详情见COMMERCE_UI_DEVICE_20261013。
