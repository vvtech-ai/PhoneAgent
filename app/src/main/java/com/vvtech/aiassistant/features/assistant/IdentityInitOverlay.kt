package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.model.WorkIdentityItem

@Composable
internal fun IdentityInitOverlay(
    saving: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onSubmit: (UserIdentityUpsertRequest) -> Unit
) {
    var name by rememberSaveable { mutableStateOf("") }
    var gender by rememberSaveable { mutableStateOf("不透露") }
    var contactPhone by rememberSaveable { mutableStateOf("") }
    var company by rememberSaveable { mutableStateOf("") }
    var department by rememberSaveable { mutableStateOf("") }
    var position by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }

    val canSave = remember(name, company, saving) {
        name.trim().isNotBlank() && company.trim().isNotBlank() && !saving
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xCC000000))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss
            )
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.82f)
                .align(Alignment.BottomCenter)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {}
                ),
            color = Color.White,
            shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 22.dp, end = 14.dp, top = 16.dp, bottom = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = stringResource(R.string.identity_init_title),
                            color = Color(0xFF111111),
                            fontSize = 19.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                        Text(
                            text = stringResource(R.string.identity_init_subtitle),
                            modifier = Modifier.padding(top = 4.dp),
                            color = Color(0xFF111111),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = stringResource(R.string.identity_init_trusted_notice),
                            modifier = Modifier.padding(top = 6.dp),
                            color = Color(0xFFE14D46),
                            fontSize = 12.sp,
                            lineHeight = 18.sp
                        )
                    }
                }

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 18.dp)
                ) {
                    if (!error.isNullOrBlank()) {
                        MyIdentityHintCard(text = error, danger = true)
                        Spacer(Modifier.size(10.dp))
                    }

                    MyIdentityFieldCardBoxed {
                        MyIdentityRequiredField(
                            label = stringResource(R.string.identity_name_label),
                            value = name,
                            placeholder = stringResource(R.string.identity_real_name_placeholder),
                            onValueChange = { name = it }
                        )
                    }

                    Spacer(Modifier.size(10.dp))
                    MyIdentityFieldCardBoxed {
                        MyIdentityGenderRow(selected = gender, onSelect = { gender = it })
                    }

                    Spacer(Modifier.size(10.dp))
                    MyIdentityFieldCardBoxed {
                        MyIdentityRow(
                            label = stringResource(R.string.identity_common_phone_label),
                            value = contactPhone,
                            placeholder = stringResource(R.string.identity_phone_placeholder),
                            keyboardType = KeyboardType.Phone,
                            onValueChange = { contactPhone = it.filter(Char::isDigit).take(11) }
                        )
                    }

                    Spacer(Modifier.size(18.dp))
                    MyIdentitySectionTitle(stringResource(R.string.identity_work_section))
                    MyIdentityFieldCardBoxed {
                        MyIdentityRequiredField(
                            label = stringResource(R.string.identity_company_label),
                            value = company,
                            placeholder = stringResource(R.string.identity_company_placeholder),
                            onValueChange = { company = it }
                        )
                    }
                    Spacer(Modifier.size(10.dp))
                    MyIdentityFieldCardBoxed {
                        MyIdentityRow(
                            label = stringResource(R.string.identity_department_label),
                            value = department,
                            placeholder = stringResource(R.string.identity_department_placeholder),
                            onValueChange = { department = it }
                        )
                    }
                    Spacer(Modifier.size(10.dp))
                    MyIdentityFieldCardBoxed {
                        MyIdentityRow(
                            label = stringResource(R.string.identity_position_label),
                            value = position,
                            placeholder = stringResource(R.string.identity_position_placeholder),
                            onValueChange = { position = it }
                        )
                    }

                    Spacer(Modifier.size(18.dp))
                    MyIdentitySectionTitle(stringResource(R.string.identity_description_section))
                    Spacer(Modifier.size(8.dp))
                    MyIdentityMultilineCard(
                        value = description,
                        placeholder = stringResource(R.string.identity_description_placeholder),
                        onValueChange = { description = it.take(2000) }
                    )

                    Spacer(Modifier.size(24.dp))
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 18.dp, end = 18.dp, top = 8.dp, bottom = 24.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    FinalActionButton(
                        label = stringResource(R.string.identity_skip),
                        tone = FinalButtonTone.Secondary,
                        modifier = Modifier.weight(1f),
                        onClick = onDismiss
                    )
                    FinalActionButton(
                        label = if (saving) {
                            stringResource(R.string.identity_saving)
                        } else {
                            stringResource(R.string.identity_save_continue)
                        },
                        tone = FinalButtonTone.Primary,
                        enabled = canSave,
                        modifier = Modifier.weight(1.6f),
                        onClick = {
                            val identities = if (company.trim().isNotBlank()) {
                                listOf(
                                    WorkIdentityItem(
                                        company = company.trim(),
                                        department = department.trim(),
                                        position = position.trim()
                                    )
                                )
                            } else emptyList()
                            onSubmit(
                                UserIdentityUpsertRequest(
                                    userId = "",
                                    name = name.trim().ifBlank { null },
                                    gender = gender.takeIf { it.isNotBlank() } ?: "不透露",
                                    contactPhone = contactPhone.trim().ifBlank { null },
                                    workIdentities = identities.ifEmpty { null },
                                    description = description.trim().ifBlank { null }
                                )
                            )
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun MyIdentityFieldCardBoxed(content: @Composable () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White,
        shape = RoundedCornerShape(16.dp),
        elevation = 0.dp
    ) {
        Column(
            modifier = Modifier.background(Color(0xFFF7F8FA), RoundedCornerShape(16.dp))
        ) { content() }
    }
}
