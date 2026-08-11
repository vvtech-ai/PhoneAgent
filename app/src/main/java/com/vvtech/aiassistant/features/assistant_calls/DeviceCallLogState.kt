package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.vvtech.aiassistant.data.local.calllog.DeviceCallLogDataSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
internal fun rememberDeviceCallLogState(
    loadEnabled: Boolean
): List<DialRecentCall> {
    val context = LocalContext.current
    val dataSource = remember(context.applicationContext) {
        DeviceCallLogDataSource(context.applicationContext)
    }
    var records by remember { mutableStateOf(emptyList<DialRecentCall>()) }
    LaunchedEffect(loadEnabled) {
        records = if (loadEnabled) {
            withContext(Dispatchers.IO) {
                dataSource.recentCalls(MaxDialRecentCalls).map(::deviceCallLogToRecentCall)
            }
        } else {
            emptyList()
        }
    }
    return records
}
