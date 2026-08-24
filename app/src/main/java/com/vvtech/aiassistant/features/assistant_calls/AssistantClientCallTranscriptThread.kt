package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.callengine.AssistantClientCallTranscript

@Composable
internal fun AssistantClientCallTranscriptThread(
    transcripts: List<AssistantClientCallTranscript>,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val latest = transcripts.getOrNull(transcripts.lastIndex)
    LaunchedEffect(transcripts.size, latest?.id, latest?.sourceText, latest?.translatedText) {
        if (transcripts.isNotEmpty()) {
            listState.animateScrollToItem(transcripts.lastIndex)
        }
    }
    if (transcripts.isEmpty()) {
        Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.call_transcript_waiting), color = Color(0xFF9AA9C3), fontSize = 15.sp)
        }
        return
    }
    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(transcripts, key = { it.id }) { transcript ->
            TranscriptMessageBubble(transcript)
        }
    }
}

@Composable
private fun TranscriptMessageBubble(transcript: AssistantClientCallTranscript) {
    val local = transcript.role.equals("local", ignoreCase = true)
    val primaryText = transcript.translatedText.ifBlank { transcript.sourceText }
    Box(
        modifier = Modifier.fillMaxWidth(),
        contentAlignment = if (local) Alignment.CenterEnd else Alignment.CenterStart
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.84f)
        ) {
            Text(
                text = if (local) stringResource(R.string.call_transcript_me) else stringResource(R.string.call_transcript_other_party),
                modifier = Modifier.padding(horizontal = 5.dp, vertical = 3.dp),
                color = Color(0xFF9EABC2),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        brush = if (local) {
                            Brush.linearGradient(listOf(Color(0xFF1687F8), Color(0xFF426EF8)))
                        } else {
                            Brush.linearGradient(listOf(Color.White, Color(0xFFF4F7FC)))
                        },
                        shape = RoundedCornerShape(
                            topStart = 18.dp,
                            topEnd = 18.dp,
                            bottomStart = if (local) 18.dp else 5.dp,
                            bottomEnd = if (local) 5.dp else 18.dp
                        )
                    )
                    .padding(horizontal = 16.dp, vertical = 13.dp)
            ) {
                Text(
                    text = primaryText,
                    color = if (local) Color.White else Color(0xFF18243A),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
                if (transcript.sourceText.isNotBlank() && transcript.sourceText != primaryText) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 9.dp)
                            .height(1.dp)
                            .background(
                                if (local) Color.White.copy(alpha = 0.22f) else Color(0xFFD9E0EA)
                            )
                    )
                    Text(
                        text = "${languageBadge(transcript.sourceLanguage)}  ${transcript.sourceText}",
                        color = if (local) Color(0xFFDCEBFF) else Color(0xFF667085),
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}

private fun languageBadge(language: String): String =
    language.trim().ifBlank { currentAppText("原文", "Original") }.uppercase()
