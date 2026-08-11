package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest

internal fun myIdentityValidationError(request: UserIdentityUpsertRequest): String? {
    if (request.name.isNullOrBlank()) {
        return "请填写姓名"
    }
    return finalUserIdentityValidationError(request)
}
