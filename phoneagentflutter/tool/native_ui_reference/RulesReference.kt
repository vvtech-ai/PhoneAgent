package com.vvtech.aiassistant.uireference

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.ModalBottomSheetLayout
import androidx.compose.material.ModalBottomSheetValue
import androidx.compose.material.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.invite.InviteActivityInfo
import com.vvtech.aiassistant.features.invite.InviteRulesSheet

/** Only the production sheet container and content; no wallet or invite service. */
@OptIn(ExperimentalMaterialApi::class)
@Composable
internal fun RulesReference(close: () -> Unit) {
    val sheet = rememberModalBottomSheetState(ModalBottomSheetValue.Expanded, skipHalfExpanded = true)
    ModalBottomSheetLayout(
        sheetState = sheet, sheetBackgroundColor = Color.White,
        sheetShape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        sheetContent = {
            InviteRulesSheet(
                InviteActivityInfo(
                    periodId = "synthetic", name = "合成活动", quota = 8,
                    inviterPoints = 0, inviteePoints = 0, bonusEnabled = false,
                    bonusThreshold = 0, bonusPoints = 0,
                    rules = "1. 仅限新用户。\n2. 积分以实际到账为准。"
                ), close
            )
        }
    ) { Box(Modifier.fillMaxSize().background(Color.White)) }
}
