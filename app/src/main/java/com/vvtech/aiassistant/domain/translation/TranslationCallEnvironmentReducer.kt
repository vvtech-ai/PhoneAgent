package com.vvtech.aiassistant.domain.translation

object TranslationCallEnvironmentReducer {
    fun apply(
        current: TranslationCallEnvironment?,
        next: TranslationCallEnvironmentPatch
    ): TranslationCallEnvironment {
        if (current != null && next.version < current.version) return current

        val network = next.network ?: current?.network ?: pendingEnvironmentComponent()
        val sip = next.sip ?: current?.sip ?: pendingEnvironmentComponent()
        val model = next.model ?: current?.model ?: pendingEnvironmentComponent()
        return TranslationCallEnvironment(
            version = next.version,
            phase = next.phase ?: current?.phase.orEmpty(),
            overallStatus = worstOf(network.state, sip.state, model.state),
            network = network,
            sip = sip,
            model = model,
            riskMessage = when {
                next.clearRiskMessage -> null
                next.riskMessage != null -> next.riskMessage
                else -> current?.riskMessage
            },
            sampledAtMs = next.sampledAtMs ?: current?.sampledAtMs ?: 0L
        )
    }

    fun worstOf(
        vararg states: TranslationEnvironmentState
    ): TranslationEnvironmentState {
        val applicable = states.filterNot {
            it == TranslationEnvironmentState.NotApplicable
        }
        if (applicable.isEmpty()) return TranslationEnvironmentState.NotApplicable
        return applicable.maxByOrNull(::severity)
            ?: TranslationEnvironmentState.NotApplicable
    }

    private fun severity(state: TranslationEnvironmentState): Int = when (state) {
        TranslationEnvironmentState.NotApplicable -> 0
        TranslationEnvironmentState.Available -> 1
        TranslationEnvironmentState.Pending -> 2
        TranslationEnvironmentState.Degraded -> 3
        TranslationEnvironmentState.Unavailable -> 4
    }
}
