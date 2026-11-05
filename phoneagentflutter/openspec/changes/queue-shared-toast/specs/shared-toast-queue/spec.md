## ADDED Requirements

### Requirement: 公共提示按调用顺序完整展示
Flutter 公共 showNativeNotice MUST 将同一Overlay的非空提示按FIFO顺序展示，同一时刻最多显示一条；前一条淡出并移除后才展示下一条，每条从实际展示开始独立计时。该规则覆盖旧最新替换规则，现有视觉、点击穿透、键盘避让及各调用方时长 MUST 保持。

#### Scenario: 同批登录赠送
- **WHEN** 服务端返回初始赠送和每日登录赠送且积分入口连续调用公共Toast
- **THEN** 两条按入队顺序各完整展示约4秒，金额来自响应，不合并金额或互相替换

#### Scenario: 不同时长与淡出中追加
- **WHEN** 不同时长的普通提示连续入队或在当前提示淡出时追加
- **THEN** 新提示等待前一条移除后开始自己的完整时长，不重新计时或截断前一条

### Requirement: 提示队列必须清理失效归属
公共提示 MUST 在主动dismiss、账号释放、所属Overlay销毁时清理当前及待展示项；不同Overlay MUST 不继承旧队列，旧销毁回调 MUST NOT 清理新队列。普通同账号导航和token刷新 MUST NOT 主动清空仍有效的队列。

#### Scenario: 主动清空和账号释放
- **WHEN** 调用dismissNativeNotice或会话导航宿主释放账号
- **THEN** 当前提示与待展示项全部清除，旧账号提示不在新账号显示

#### Scenario: Overlay销毁和重建
- **WHEN** 含提示的Overlay销毁后建立新Overlay并显示提示
- **THEN** 旧队列不再推进，旧组件销毁回调不影响新提示，无计时器或挂载异常
