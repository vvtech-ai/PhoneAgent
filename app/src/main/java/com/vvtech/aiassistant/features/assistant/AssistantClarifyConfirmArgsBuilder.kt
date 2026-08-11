package com.vvtech.aiassistant.features.assistant

internal class AssistantClarifyConfirmArgsBuilderInput(
    val options: ClarifyConfirmOptionsInput,
    val selection: ClarifyConfirmSelectionInput,
    val confirmation: ClarifyConfirmConfirmationInput,
    val callbacks: ClarifyConfirmCallbacksInput
)

internal class ClarifyConfirmOptionsInput(
    val restaurantOptions: List<FinalOption>,
    val fallbackOptions: List<FinalOption>,
    val selectedRestaurant: FinalOption?,
    val selectedFallbacks: List<FinalOption>,
    val defaultMethod: PersonalInfoEntry?
)

internal class ClarifyConfirmSelectionInput(
    val selectedRestaurantId: String?,
    val selectedFallbackIds: MutableList<String>,
    val requiredFallbackIds: MutableList<String>
)

internal class ClarifyConfirmConfirmationInput(
    val restaurantConfirmed: Boolean,
    val fallbackConfirmed: Boolean,
    val confirmingRestaurantId: String?,
    val confirmingFallbackId: String?,
    val confirmAttachmentUploaded: Boolean,
    val storagePermissionGranted: Boolean
)

internal class ClarifyConfirmCallbacksInput(
    val onSelectedRestaurantIdChange: (String?) -> Unit,
    val onRestaurantConfirmedChange: (Boolean) -> Unit,
    val onConfirmingRestaurantIdChange: (String?) -> Unit,
    val onFallbackConfirmedChange: (Boolean) -> Unit,
    val onConfirmingFallbackIdChange: (String?) -> Unit,
    val onConfirmAttachmentUploadedChange: (Boolean) -> Unit,
    val blockIfOffline: () -> Boolean,
    val onRequestedPermissionNameChange: (String?) -> Unit,
    val onPendingPermissionActionChange: (String) -> Unit
)

internal fun buildAssistantClarifyConfirmArgs(
    input: AssistantClarifyConfirmArgsBuilderInput
): ConfirmClarifyArgs = ConfirmClarifyArgs().also { args ->
    with(input.options) {
        args.restaurantOptions = restaurantOptions
        args.fallbackOptions = fallbackOptions
        args.selectedRestaurant = selectedRestaurant
        args.selectedFallbacks = selectedFallbacks
        args.defaultMethod = defaultMethod
    }
    with(input.selection) {
        args.selectedRestaurantId = selectedRestaurantId
        args.selectedFallbackIds = selectedFallbackIds
        args.requiredFallbackIds = requiredFallbackIds
    }
    with(input.confirmation) {
        args.restaurantConfirmed = restaurantConfirmed
        args.fallbackConfirmed = fallbackConfirmed
        args.confirmingRestaurantId = confirmingRestaurantId
        args.confirmingFallbackId = confirmingFallbackId
        args.confirmAttachmentUploaded = confirmAttachmentUploaded
        args.storagePermissionGranted = storagePermissionGranted
    }
    with(input.callbacks) {
        args.onSelectedRestaurantIdChange = onSelectedRestaurantIdChange
        args.onRestaurantConfirmedChange = onRestaurantConfirmedChange
        args.onConfirmingRestaurantIdChange = onConfirmingRestaurantIdChange
        args.onFallbackConfirmedChange = onFallbackConfirmedChange
        args.onConfirmingFallbackIdChange = onConfirmingFallbackIdChange
        args.onConfirmAttachmentUploadedChange = onConfirmAttachmentUploadedChange
        args.blockIfOffline = blockIfOffline
        args.onRequestedPermissionNameChange = onRequestedPermissionNameChange
        args.onPendingPermissionActionChange = onPendingPermissionActionChange
    }
}
