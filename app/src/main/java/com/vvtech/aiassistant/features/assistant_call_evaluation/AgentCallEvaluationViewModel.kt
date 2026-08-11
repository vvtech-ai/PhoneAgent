package com.vvtech.aiassistant.features.assistant_call_evaluation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.data.repository.evaluation.AgentCallEvaluationRepository
import com.vvtech.aiassistant.data.repository.evaluation.AgentCallEvaluationRepositoryProvider
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class AgentCallEvaluationViewModel(
    private val target: AgentCallEvaluationTarget,
    private val repository: AgentCallEvaluationRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AgentCallEvaluationUiState())
    val state: StateFlow<AgentCallEvaluationUiState> = mutableState.asStateFlow()
    private var job: Job? = null

    init {
        load()
    }

    fun rate(rating: AgentCallRating) {
        if (mutableState.value.saving) return
        val previous = mutableState.value.rating
        mutableState.update { it.copy(rating = rating, saving = true, message = null) }
        job?.cancel()
        job = viewModelScope.launch {
            runCatching {
                when (target) {
                    is AgentCallEvaluationTarget.Call -> repository.rate(target.id, rating.wireValue)
                    is AgentCallEvaluationTarget.Batch -> repository.rateBatch(target.id, rating.wireValue)
                }
            }
                .onSuccess { result -> mutableState.value = result.toUiState() }
                .onFailure {
                    mutableState.update {
                        it.copy(rating = previous, saving = false, message = "评价提交失败，请重试")
                    }
                }
        }
    }

    private fun load() {
        job?.cancel()
        job = viewModelScope.launch {
            runCatching {
                when (target) {
                    is AgentCallEvaluationTarget.Call -> repository.get(target.id)
                    is AgentCallEvaluationTarget.Batch -> repository.getBatch(target.id)
                }
            }
                .onSuccess { mutableState.value = it.toUiState() }
                .onFailure { mutableState.value = AgentCallEvaluationUiState() }
        }
    }
}

internal class AgentCallEvaluationViewModelFactory(
    private val target: AgentCallEvaluationTarget,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(AgentCallEvaluationViewModel::class.java))
        return AgentCallEvaluationViewModel(
            target,
            AgentCallEvaluationRepositoryProvider.repository,
        ) as T
    }
}

internal sealed interface AgentCallEvaluationTarget {
    val id: String

    data class Call(override val id: String) : AgentCallEvaluationTarget
    data class Batch(override val id: String) : AgentCallEvaluationTarget
}
