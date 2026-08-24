package com.vvtech.aiassistant.features.assistant_calls

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBackIosNew
import androidx.compose.material.icons.filled.Search
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
internal fun DialCountrySelectorPage(
    selectedIso: String,
    onSelect: (String) -> Unit,
    onLocationCountrySelected: (String) -> Unit,
    onBack: () -> Unit
) {
    BackHandler(onBack = onBack)
    var query by remember { mutableStateOf("") }
    var indexFeedback by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val locationState = rememberDialCountryLocationState()
    val items = remember(query) { buildDialCountryListItems(query) }
    val sectionPositions = remember(items) {
        items.mapIndexedNotNull { index, item ->
            (item as? DialCountryListItem.Header)?.title?.let { it to index }
        }.toMap()
    }
    val alphabetSections = remember(items) { dialCountryAlphabetSections(items) }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color(0xFFF8F9FC))
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Column(Modifier.fillMaxSize()) {
            DialCountrySelectorHeader(onBack)
            DialCountrySearchField(query = query, onQueryChange = { query = it })
            LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                item {
                    val state = locationState
                    val resolved = state.country?.iso
                    DialCountryLocationSection(
                        state = state,
                        onClick = {
                            resolved?.let(onLocationCountrySelected) ?: state.requestLocation()
                        }
                    )
                }
                dialCountryListContent(items = items, selectedIso = selectedIso, onSelect = onSelect)
            }
        }
        if (query.isBlank()) {
            DialCountryAlphabetIndex(
                modifier = Modifier.align(Alignment.CenterEnd),
                sections = alphabetSections,
                onSection = { section ->
                    sectionPositions[section]?.let { target ->
                        indexFeedback = section
                        scope.launch { listState.scrollToItem(target + 1) }
                    }
                }
            )
        }
        indexFeedback?.let { section ->
            Box(
                Modifier
                    .align(Alignment.Center)
                    .size(72.dp)
                    .background(Color(0xCC344054), RoundedCornerShape(18.dp)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    section,
                    color = Color.White,
                    fontSize = if (section == "G20") 22.sp else 32.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            LaunchedEffect(section) {
                delay(550)
                if (indexFeedback == section) indexFeedback = null
            }
        }
    }
}

@Composable
private fun DialCountrySelectorHeader(onBack: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(start = 10.dp, end = 20.dp, top = 18.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.size(42.dp).clickable(onClick = onBack),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.ArrowBackIosNew,
                contentDescription = stringResource(R.string.common_back),
                tint = Color(0xFF111318),
                modifier = Modifier.size(19.dp)
            )
        }
        Text(
            stringResource(R.string.dial_select_country),
            color = Color(0xFF111318),
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun DialCountrySearchField(query: String, onQueryChange: (String) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp)
            .background(Color(0xFFEFF1F5), RoundedCornerShape(14.dp))
            .padding(horizontal = 13.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            Icons.Default.Search,
            contentDescription = null,
            tint = Color(0xFF98A2B3),
            modifier = Modifier.size(20.dp)
        )
        BasicTextField(
            value = query,
            onValueChange = onQueryChange,
            modifier = Modifier.weight(1f).padding(start = 8.dp),
            textStyle = TextStyle(color = Color(0xFF202228), fontSize = 15.sp),
            singleLine = true,
            decorationBox = { inner ->
                if (query.isBlank()) {
                    Text(
                        stringResource(R.string.dial_country_search_placeholder),
                        color = Color(0xFF98A2B3),
                        fontSize = 15.sp
                    )
                }
                inner()
            }
        )
    }
}

@Composable
private fun DialCountryAlphabetIndex(
    modifier: Modifier,
    sections: List<String>,
    onSection: (String) -> Unit
) {
    var heightPx by remember { mutableStateOf(1) }
    Column(
        modifier
            .padding(end = 3.dp)
            .onSizeChanged { heightPx = it.height.coerceAtLeast(1) }
            .pointerInput(heightPx) {
                fun select(y: Float) {
                    val index = ((y / heightPx) * sections.size)
                        .toInt()
                        .coerceIn(0, sections.lastIndex)
                    onSection(sections[index])
                }
                detectDragGestures(
                    onDragStart = { select(it.y) },
                    onDrag = { change, _ -> select(change.position.y) }
                )
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        sections.forEach { section ->
            Text(
                section,
                modifier = Modifier
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { onSection(section) }
                    .padding(vertical = 0.5.dp),
                color = Color(0xFF1687F8),
                fontSize = if (section == "G20") 8.sp else 9.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
