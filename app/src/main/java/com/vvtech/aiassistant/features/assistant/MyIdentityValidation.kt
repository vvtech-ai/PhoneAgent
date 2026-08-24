package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun myIdentityValidationError(request: UserIdentityUpsertRequest): String? {
    if (request.name.isNullOrBlank()) {
        return currentAppText("请填写姓名", "Enter your name")
    }
    return finalUserIdentityValidationError(request)
}
