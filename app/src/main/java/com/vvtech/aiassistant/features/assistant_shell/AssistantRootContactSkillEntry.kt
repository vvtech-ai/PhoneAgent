package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore
import com.vvtech.aiassistant.features.assistant_contacts.buildAssistantContactSkillOpening

internal fun AssistantRootHostActionDeps.startContactSkill(
    skillId: String,
    selectedContact: SelectedContactTaskContext
): Boolean = voiceEntry.startVoiceEntry(
    initialCommand = null,
    startWithVoice = true,
    resumeExisting = false,
    initialSkillId = skillId,
    initialSkillOpening = buildAssistantContactSkillOpening(
        skillId = skillId,
        contactName = selectedContact.name,
        fallbackOpening = AgentInitialSkillLaunchStore.peekOpening()
    ),
    selectedContact = selectedContact
)
