enum ConversationPrecheckStage { network, model, outbound, passed, complete }

enum ConversationPrecheckItemState { checking, passed, warning, blocked }

class ConversationPrecheckItem {
  const ConversationPrecheckItem(this.title, this.detail, this.state);
  final String title, detail;
  final ConversationPrecheckItemState state;
}

/// Original v66 display projection; it never admits or starts a call.
class ConversationPrecheckPresentation {
  const ConversationPrecheckPresentation(
    this.visible,
    this.blocked,
    this.items,
  );
  final bool visible, blocked;
  final List<ConversationPrecheckItem> items;

  factory ConversationPrecheckPresentation.from({
    required ConversationPrecheckStage stage,
    required bool networkUnavailable,
    required bool weakNetwork,
    required bool modelReady,
    required bool modelBlocked,
    required String modelName,
    required String modelError,
  }) {
    const checking = ConversationPrecheckItemState.checking;
    const passed = ConversationPrecheckItemState.passed;
    const warning = ConversationPrecheckItemState.warning;
    const failed = ConversationPrecheckItemState.blocked;
    final network = networkUnavailable
        ? const ConversationPrecheckItem('网络连接', '网络连接不可用', failed)
        : stage == ConversationPrecheckStage.network
        ? const ConversationPrecheckItem('网络连接', '正在检查网络连接', checking)
        : weakNetwork
        ? const ConversationPrecheckItem('网络连接', '网络连接较弱', warning)
        : const ConversationPrecheckItem('网络连接', '网络连接正常', passed);
    final model = modelBlocked
        ? ConversationPrecheckItem(
            '大模型服务',
            modelError.isNotEmpty ? modelError : '$modelName 未配置或不可用',
            failed,
          )
        : stage == ConversationPrecheckStage.network
        ? const ConversationPrecheckItem('大模型服务', '等待检测', warning)
        : stage == ConversationPrecheckStage.model
        ? const ConversationPrecheckItem('大模型服务', '正在连接大模型服务', checking)
        : modelReady
        ? ConversationPrecheckItem('大模型服务', '$modelName 已就绪', passed)
        : const ConversationPrecheckItem('大模型服务', '正在连接大模型服务', warning);
    final outbound = switch (stage) {
      ConversationPrecheckStage.network || ConversationPrecheckStage.model =>
        const ConversationPrecheckItem('外呼通道', '等待检测', warning),
      ConversationPrecheckStage.outbound => const ConversationPrecheckItem(
        '外呼通道',
        '正在检查外呼通道',
        checking,
      ),
      ConversationPrecheckStage.passed => const ConversationPrecheckItem(
        '外呼通道',
        '外呼通道已就绪',
        passed,
      ),
      ConversationPrecheckStage.complete => ConversationPrecheckItem(
        '外呼通道',
        modelReady ? '执行通话前校验外呼通道' : '等待检测',
        warning,
      ),
    };
    final blocked = networkUnavailable || modelBlocked;
    return ConversationPrecheckPresentation(
      stage != ConversationPrecheckStage.complete || blocked || !modelReady,
      blocked,
      List.unmodifiable([network, model, outbound]),
    );
  }

  String get label {
    if (!visible) return '';
    for (final item in items) {
      if (item.state == ConversationPrecheckItemState.blocked) {
        return '${item.title}不可用';
      }
    }
    for (final item in items) {
      if (item.state == ConversationPrecheckItemState.checking) {
        return item.detail;
      }
    }
    if (items[1].state == ConversationPrecheckItemState.warning) {
      return '正在连接大模型服务';
    }
    return '任务执行环境检测通过';
  }
}
