package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable

@Composable
internal fun AssistantClarifyConfirmPageHost(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    confirmClarify: ConfirmClarifyArgs
) {
    with(navigation) {
        with(confirmClarify) {
            when (targetPage) {
                FinalPage.Clarify -> FinalClarifyPageV3(
                    FinalClarifyPageArgs(
                        state = FinalClarifyPageState(
                            restaurantOptions = restaurantOptions,
                            fallbackOptions = fallbackOptions,
                            selectedRestaurantId = selectedRestaurantId,
                            selectedFallbackIds = selectedFallbackIds.toList(),
                            requiredFallbackIds = requiredFallbackIds.toList(),
                            restaurantConfirmed = restaurantConfirmed,
                            fallbackConfirmed = fallbackConfirmed,
                            restaurantConfirming = confirmingRestaurantId != null,
                            fallbackConfirming = confirmingFallbackId != null
                        ),
                        callbacks = FinalClarifyPageCallbacks(
                            onBack = { onPageChange(FinalPage.Assistant) },
                            onStop = { onPageChange(FinalPage.Assistant) },
                            onSelectRestaurant = {
                                onSelectedRestaurantIdChange(it)
                                onRestaurantConfirmedChange(false)
                                onConfirmingRestaurantIdChange(null)
                                selectedFallbackIds.clear()
                                requiredFallbackIds.clear()
                                onFallbackConfirmedChange(false)
                                onConfirmingFallbackIdChange(null)
                            },
                            onConfirmRestaurant = onConfirmRestaurant@{
                                val targetId = selectedRestaurantId ?: return@onConfirmRestaurant
                                if (!restaurantConfirmed && confirmingRestaurantId == null) {
                                    onConfirmingRestaurantIdChange(targetId)
                                }
                            },
                            onToggleFallbackSelect = { id ->
                                if (selectedFallbackIds.contains(id)) {
                                    selectedFallbackIds.remove(id)
                                    requiredFallbackIds.remove(id)
                                } else {
                                    selectedFallbackIds.add(id)
                                }
                                onFallbackConfirmedChange(false)
                                onConfirmingFallbackIdChange(null)
                            },
                            onToggleFallbackRequired = onToggleFallbackRequired@{ id, required ->
                                if (!selectedFallbackIds.contains(id)) {
                                    requiredFallbackIds.remove(id)
                                    return@onToggleFallbackRequired
                                }
                                if (required) {
                                    if (!requiredFallbackIds.contains(id)) requiredFallbackIds.add(id)
                                } else {
                                    requiredFallbackIds.remove(id)
                                }
                                onFallbackConfirmedChange(false)
                                onConfirmingFallbackIdChange(null)
                            },
                            onConfirmFallback = {
                                if (restaurantConfirmed && !fallbackConfirmed && confirmingFallbackId == null) {
                                    if (selectedFallbackIds.isNotEmpty()) {
                                        onConfirmingFallbackIdChange("fallback_multi")
                                    }
                                }
                            },
                            onNext = {
                                if (restaurantConfirmed && fallbackConfirmed && selectedFallbackIds.isNotEmpty()) {
                                    onOpenSubPage(FinalPage.Confirm)
                                }
                            }
                        )
                    )
                )

                FinalPage.Confirm -> FinalConfirmPageV3(
                    restaurantName = selectedRestaurant?.title ?: "待确认餐厅",
                    fallbackPlan = selectedFallbacks.joinToString("、") { option ->
                        val status = if (requiredFallbackIds.contains(option.id)) "必须满足" else "提及但不必须"
                        "${option.title}：$status"
                    }.ifBlank { "待确认处理方式" },
                    contactMethod = defaultMethod,
                    attachmentUploaded = confirmAttachmentUploaded,
                    onBack = { onPageChange(FinalPage.Clarify) },
                    onStop = { onPageChange(FinalPage.Clarify) },
                    onOpenContactMethods = { onOpenSubPage(FinalPage.ContactMethods) },
                    onUploadAttachment = {
                        if (!blockIfOffline()) {
                            if (storagePermissionGranted) {
                                onConfirmAttachmentUploadedChange(true)
                            } else {
                                onRequestedPermissionNameChange(V88PermissionKind.Storage.name)
                                onPendingPermissionActionChange("upload_attachment")
                            }
                        }
                    },
                    onConfirm = {
                        if (defaultMethod != null) {
                            onOpenSubPage(FinalPage.AiCall)
                        } else {
                            onOpenSubPage(FinalPage.ContactMethods)
                        }
                    }
                )

                else -> Unit
            }
        }
    }
}
