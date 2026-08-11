package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

internal sealed interface DialCountryListItem {
    data class Header(val title: String) : DialCountryListItem
    data class Country(val value: DialCountry, val inG20: Boolean = false) : DialCountryListItem
}

internal fun LazyListScope.dialCountryListContent(
    items: List<DialCountryListItem>,
    selectedIso: String,
    onSelect: (String) -> Unit
) {
    if (items.isEmpty()) {
        item {
            Box(
                Modifier.fillMaxWidth().padding(top = 48.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("暂无匹配的国家或地区", color = Color(0xFF98A2B3), fontSize = 14.sp)
            }
        }
    }
    items(items, key = ::dialCountryItemKey) { item ->
        when (item) {
            is DialCountryListItem.Header -> DialCountrySectionHeader(item.title)
            is DialCountryListItem.Country -> DialCountryRow(
                country = item.value,
                selected = item.value.iso == selectedIso,
                onClick = { onSelect(item.value.iso) }
            )
        }
    }
}

@Composable
internal fun DialCountryLocationSection(
    state: DialCountryLocationState,
    onClick: () -> Unit
) {
    val working = state.status == DialCountryLocationStatus.LOCATING ||
        state.status == DialCountryLocationStatus.REQUESTING_PERMISSION
    val resolved = state.country
    val idle = state.status == DialCountryLocationStatus.IDLE ||
        state.status == DialCountryLocationStatus.DENIED ||
        state.status == DialCountryLocationStatus.BLOCKED ||
        state.status == DialCountryLocationStatus.UNSUPPORTED ||
        state.status == DialCountryLocationStatus.FAILED
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable(enabled = !working, onClick = onClick),
        color = if (resolved != null) Color(0x0A0A84FF) else Color(0x093C3C43),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(
            1.dp,
            if (resolved != null) Color(0x290A84FF) else Color(0x1A3C3C43)
        ),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (resolved == null) {
                Text(
                    "●",
                    modifier = Modifier.padding(end = 8.dp),
                    color = Color(0xFF0A84FF),
                    fontSize = 13.sp
                )
            } else {
                DialCountryFlagIcon(
                    resolved.iso,
                    modifier = Modifier.padding(end = 8.dp).size(width = 26.dp, height = 18.dp)
                )
            }
            Text("当前位置", color = Color(0xFF6E6E73), fontSize = 12.sp)
            Text(
                text = resolved?.name ?: state.message,
                modifier = Modifier.weight(1f).padding(start = 10.dp),
                color = if (resolved != null) Color(0xFF111318) else Color(0xFF667085),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (resolved != null) {
                Text(
                    resolved.dialCode,
                    color = Color(0xFF0A3A7A),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.ExtraBold
                )
            } else if (idle && !working) {
                Surface(color = Color(0x140A84FF), shape = RoundedCornerShape(9.dp), elevation = 0.dp) {
                    Text(
                        text = state.actionLabel,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
                        color = Color(0xFF0A84FF),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun DialCountrySectionHeader(title: String) {
    Text(
        title,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFFF1F3F7))
            .padding(horizontal = 20.dp, vertical = 7.dp),
        color = Color(0xFF667085),
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold
    )
}

@Composable
private fun DialCountryRow(country: DialCountry, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        DialCountryFlagIcon(country.iso, modifier = Modifier.size(width = 26.dp, height = 18.dp))
        Row(
            modifier = Modifier.weight(1f).padding(start = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = country.name,
                modifier = Modifier.weight(1f, fill = false),
                color = Color(0xFF202228),
                fontSize = 15.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(country.dialCode, color = Color(0xFF667085), fontSize = 14.sp)
        }
        Box(Modifier.size(30.dp), contentAlignment = Alignment.Center) {
            if (selected) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = "已选择",
                    tint = Color(0xFF1687F8),
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

internal fun buildDialCountryListItems(query: String): List<DialCountryListItem> {
    val normalized = query.trim().lowercase().replace(" ", "")
    if (normalized.isNotEmpty()) {
        return DialCountries.filter {
            it.name.contains(normalized, ignoreCase = true) ||
                it.iso.lowercase().contains(normalized) ||
                it.pinyin.contains(normalized) ||
                it.initials.contains(normalized) ||
                it.dialCode.contains(normalized)
        }.map { DialCountryListItem.Country(it) }
    }
    return buildList {
        add(DialCountryListItem.Header("G20"))
        DialCountries.filter { it.g20 }.forEach {
            add(DialCountryListItem.Country(it, inG20 = true))
        }
        DialCountries.groupBy { it.section }.toSortedMap().forEach { (section, countries) ->
            add(DialCountryListItem.Header(section.toString()))
            countries.forEach { add(DialCountryListItem.Country(it)) }
        }
    }
}

internal fun dialCountryAlphabetSections(
    items: List<DialCountryListItem>
): List<String> = items.mapNotNull { item ->
    (item as? DialCountryListItem.Header)?.title
}.distinct()

private fun dialCountryItemKey(item: DialCountryListItem): String = when (item) {
    is DialCountryListItem.Header -> "header-${item.title}"
    is DialCountryListItem.Country -> "${if (item.inG20) "g20" else "all"}-${item.value.iso}"
}
