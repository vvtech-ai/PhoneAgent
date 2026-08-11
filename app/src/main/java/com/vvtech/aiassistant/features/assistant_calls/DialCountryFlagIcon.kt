package com.vvtech.aiassistant.features.assistant_calls

import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import com.vvtech.aiassistant.R

@Composable
internal fun DialCountryFlagIcon(countryIso: String, modifier: Modifier = Modifier) {
    val resourceId = dialCountryFlagResource(countryIso) ?: return
    Image(
        painter = painterResource(resourceId),
        contentDescription = null,
        modifier = modifier.clip(RoundedCornerShape(2.dp)),
        contentScale = ContentScale.Crop
    )
}

internal fun dialCountryFlagResource(countryIso: String): Int? =
    when (countryIso.trim().uppercase()) {
        "CN" -> R.drawable.flag_dial_cn
        "JP" -> R.drawable.flag_dial_jp
        "SG" -> R.drawable.flag_dial_sg
        "US" -> R.drawable.flag_dial_us
        else -> null
    }
