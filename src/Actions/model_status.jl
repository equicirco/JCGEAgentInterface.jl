"""
Read-only diagnostic status for a registered model study.
"""
module ModelStatus

using ..Schema: ActionRequest, response
using ..Context: AgentContext, active_model_adapter, model_adapter
using ..Context: provenance_records
using ..Adapters: adapter_summary, compatibility_status
using ..Catalog: package_version_map

export handler

function _selected_adapter(req::ActionRequest, ctx::AgentContext)
    if haskey(req.payload, :model)
        adapter = model_adapter(ctx, String(req.payload[:model]))
        adapter === nothing && return nothing, "Unknown model $(req.payload[:model])"
        return adapter, nothing
    end
    adapter = active_model_adapter(ctx)
    adapter === nothing && return nothing, "No model is loaded. Use load_model first."
    return adapter, nothing
end

function _next_actions(ctx::AgentContext, adapter, compatibility)
    actions = String[]
    compatibility[:compatible] || return ["jcge_list_models", "jcge_package_status"]
    if adapter.calibrate !== nothing &&
       !(ctx.calibration_available && ctx.calibration_model == adapter.name)
        push!(actions, "jcge_calibrate_model")
    end
    !isempty(adapter.scenarios) && push!(actions, "jcge_run_scenario")
    !isempty(adapter.experiments) && push!(actions, "jcge_run_experiment")
    push!(actions, "jcge_solve")
    if ctx.result_model == adapter.name && ctx.last_result !== nothing
        push!(actions, "jcge_validate_model")
    end
    workflow_available = ctx.workflow_model == adapter.name && ctx.last_workflow !== nothing
    solved_available = ctx.result_model == adapter.name && ctx.last_result !== nothing
    (!isempty(adapter.reporters) && (workflow_available || solved_available)) &&
        push!(actions, "jcge_run_reporter")
    push!(actions, "jcge_provenance")
    return actions
end

"""
    handler(req; ctx=nothing)

Return a read-only readiness snapshot; it never builds, calibrates, solves, or
calls a model-owned callback.
"""
function handler(req::ActionRequest; ctx=nothing)
    ctx isa AgentContext || return response(req.id; ok=false, error="No agent context is available.")
    adapter, selection_error = _selected_adapter(req, ctx)
    selection_error === nothing || return response(req.id; ok=false, error=selection_error)
    compatibility = compatibility_status(adapter, package_version_map())
    workflow_available = ctx.workflow_model == adapter.name && ctx.last_workflow !== nothing
    solved_available = ctx.result_model == adapter.name && ctx.last_result !== nothing
    report_available = ctx.report_model == adapter.name && ctx.last_report !== nothing
    return response(req.id; data=Dict(
        :model => adapter.name,
        :adapter => adapter_summary(adapter),
        :compatibility => compatibility,
        :calibration => Dict(
            :declared => adapter.calibrate !== nothing,
            :available => ctx.calibration_available && ctx.calibration_model == adapter.name,
            :check_declared => adapter.check_calibration !== nothing,
        ),
        :workflow => Dict(
            :available => workflow_available,
            :kind => workflow_available ? String(ctx.workflow_kind) : nothing,
            :name => workflow_available ? ctx.workflow_name : nothing,
        ),
        :solve => Dict(:available => solved_available),
        :report => Dict(
            :available => report_available,
            :name => report_available ? ctx.report_name : nothing,
        ),
        :provenance_records => length(provenance_records(ctx)),
        :next_actions => _next_actions(ctx, adapter, compatibility),
    ))
end

end # module
