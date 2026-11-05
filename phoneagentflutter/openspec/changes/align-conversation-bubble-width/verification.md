# 验证记录

## 基线与源码

- Flutter：codex/dev，0b61e228；fetch 后 origin/codex/dev 无新增提交，工作树起始干净。
- 旧原生：只读 origin/test/v66.0.3，a0bedb12；同时核对 aiassistant-app/feature/test_v1.6.0 的 PureVoiceBubble。
- 修改仅三个 conversation 展示源码；普通气泡恢复角色上限，选项按标题显示模式选择宽度，道歉说明填宽。确认、回执、工具及思考组件不改状态或样式。

## 失败证据与修复

新增 native_bubble_width_test 在原代码390屏宽正常字体下测得普通AI气泡284，超过旧版260上限，失败后才修改源码。最终断言保留短文本自适应，长文本允许不足一个字宽的自然留白。没有为了所有卡右边缘相同而强制拉伸普通短气泡。

旧测试两处比例断言改为旧原生角色上限；双倍字号的用户“已收到你的选择。”在220上限内应自然换行，更新为两行且内容完整，其他短消息仍一行。

## 已执行

`flutter test` 下列14文件：111项通过。

- native_bubble_width_test.dart：双平台、240/320/390/430、1/2倍字号，AI左/用户右、长短消息、道歉说明与无标题选项同宽及选项点击。
- native_dialogue_card_alignment_test.dart：双平台、320/390/430、1/2倍字号，工具、单路确认、多路摘要/规则、单路转写/结果、多路结果的旧版宽度和左边缘。
- native_conversation_short_text_test.dart、native_message_paragraph_test.dart、native_mixed_message_spacing_test.dart、native_option_title_test.dart、native_tool_card_ui_test.dart、native_conversation_layout_test.dart、conversation_message_tile_test.dart、restaurant_option_card_test.dart。
- apology_committed_timeline_test.dart、playback_context_controls_test.dart、ocr_initial_opening_order_test.dart、document_opening_order_test.dart：回归道歉历史、播报控件与图片/Word/Excel开场顺序。

`flutter analyze`：无问题。`openspec validate --all`：220通过、0失败。

## 范围与待验

未改后端、接口、数据库或包版本，未构建新包、未操作设备或真实外呼。自动测试证明组件坐标及已有交互回归通过；真机视觉验收待用户，change保留active。
