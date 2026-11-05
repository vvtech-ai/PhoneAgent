package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.points.PointsLedgerScreen
import com.vvtech.aiassistant.features.points.PointsLedgerUiItem
import com.vvtech.aiassistant.features.points.PointsWalletUiState

/** Same synthetic states as Flutter; all business actions are absent. */
@Composable
internal fun LedgerReference(scene: String, close: () -> Unit) {
    PointsLedgerScreen(
        state = PointsWalletUiState(
            ledgerAvailable = scene == "ledger" || scene == "ledger-empty",
            loading = scene == "ledger-loading",
            error = if (scene == "ledger-error")
                "网络连接异常，暂时无法更新积分流水，请检查网络后重试" else null,
            items = if (scene == "ledger") listOf(
                PointsLedgerUiItem(1, "每日登录赠送", 100, 900,
                    "每日登录赠送", "2026-09-20T09:00:00"),
                PointsLedgerUiItem(2, "通话扣费", -20, 880,
                    "合成通话1分钟", "2026-09-20T09:01:00"),
                PointsLedgerUiItem(3, "合成零变更", 0, 880,
                    "无积分变更", "2026-09-20T09:02:00")
            ) else emptyList(),
            hasNext = scene == "ledger"
        ),
        onBack = close, onRefresh = {}, onLoadNext = {}
    )
}
