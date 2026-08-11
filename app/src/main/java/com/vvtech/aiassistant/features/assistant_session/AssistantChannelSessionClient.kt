package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.ContactResolutionPayload
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultUserId
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel

internal class AssistantChannelSessionClient(
    private val viewModel: AssistantViewModel
) {
    private val sessionTurnUseCase = AssistantSessionTurnUseCase(viewModel.repository)

    suspend fun ensureTextSession(): String {
        val existingTaskId = viewModel.textTaskId?.takeIf { it.isNotBlank() }
        if (existingTaskId != null) {
            return existingTaskId
        }
        val session = sessionTurnUseCase.startTextSession(
            AssistantTextSessionStartInput(
                userId = DefaultUserId,
                userContext = viewModel.latestUserContext,
                languageCode = viewModel.voiceLanguageCode
            )
        )
        viewModel.textTaskId = session.session.taskId
        return session.session.taskId
    }

    suspend fun sendActionThroughActiveChannel(
        actionId: String,
        actionLabel: String?
    ): AssistantSessionResponse {
        val isCallAction = actionId.contains("execute", ignoreCase = true)
        val taskId = if (isCallAction) {
            viewModel.internalUiState.value.taskId ?: viewModel.voiceTaskId ?: ensureTextSession()
        } else {
            ensureTextSession()
        }
        viewModel.internalLog(
            "sendActionThroughActiveChannel actionId=$actionId taskId=$taskId isCallAction=$isCallAction"
        )
        return sessionTurnUseCase.sendTextTurn(
            AssistantTextTurnInput(
                userId = DefaultUserId,
                taskId = taskId,
                actionId = actionId,
                actionLabel = actionLabel,
                userContext = viewModel.latestUserContext,
                languageCode = viewModel.voiceLanguageCode
            )
        )
    }

    fun applyChannelSession(session: AssistantSessionResponse) {
        if (viewModel.activeInteractionChannel == InteractionChannel.TEXT) {
            viewModel.applyTextSession(session)
        } else {
            viewModel.applySession(session)
        }
    }

    suspend fun sendDetailSupplementPayload(
        syncPayload: String,
        fallbackTaskId: String
    ): AssistantSessionResponse {
        return if (viewModel.activeInteractionChannel == InteractionChannel.TEXT) {
            val ensuredTaskId = ensureTextSession()
            sessionTurnUseCase.sendTextTurn(
                AssistantTextTurnInput(
                    userId = DefaultUserId,
                    taskId = ensuredTaskId,
                    message = syncPayload,
                    userContext = viewModel.latestUserContext,
                    contactResolution = resolveContactPayload(syncPayload),
                    languageCode = viewModel.voiceLanguageCode
                )
            )
        } else {
            sessionTurnUseCase.sendVoiceMessage(
                AssistantVoiceMessageInput(
                    userId = DefaultUserId,
                    taskId = viewModel.voiceTaskId ?: fallbackTaskId,
                    startFresh = false,
                    message = syncPayload,
                    userContext = viewModel.latestUserContext,
                    contactResolution = resolveContactPayload(syncPayload),
                    languageCode = viewModel.voiceLanguageCode
                )
            )
        }
    }

    suspend fun resolveContactPayload(message: String): ContactResolutionPayload? {
        val contactsGranted = ContextCompat.checkSelfPermission(
            viewModel.appContext,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        if (!contactsGranted) return null

        val candidate = DeviceContactResolver.extractCallContactCandidate(message)
        if (candidate != null) {
            val result = runCatching {
                DeviceContactResolver(viewModel.appContext).findPhoneByDisplayName(candidate.contactName)
            }.getOrNull() ?: return null
            return if (result.found && !result.phoneNumber.isNullOrBlank()) {
                ContactResolutionPayload(
                    contactName = result.contactName,
                    phoneNumber = result.phoneNumber,
                    status = "FOUND"
                )
            } else {
                ContactResolutionPayload(
                    contactName = candidate.contactName,
                    status = "NOT_FOUND"
                )
            }
        }

        val explicit = DeviceContactResolver.extractExplicitContact(message)
        if (explicit != null) {
            viewModel.internalLog(
                "resolveContactPayload explicitContact name=${explicit.contactName} phone=${explicit.phoneNumber}"
            )
            return ContactResolutionPayload(
                contactName = explicit.contactName,
                phoneNumber = explicit.phoneNumber,
                status = "FOUND"
            )
        }

        return null
    }
}
