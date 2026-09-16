"""
Run named model-owned scenario and experiment workflows.
"""
module RunWorkflow

using ..Schema: ActionRequest, response
using ..Context: AgentContext, active_model_adapter, model_adapter, record_provenance!
using ..Adapters: WorkflowState, workflow_parameter_status, run_workflow
using ..Catalog: package_inventory

export scenario_handler, experiment_handler

function _selected_adapter(req::ActionRequest, ctx::AgentContext)
    if haskey(req.payload, :model)
        adapter = model_adapter(ctx, String(req.payload[:model]))
        adapter === nothing && return nothing, "Unknown model $(req.payload[:model])"
        ctx.active_model = adapter.name
        return adapter, nothing
    end
    adapter = active_model_adapter(ctx)
    adapter === nothing && return nothing, "No model is loaded. Use load_model first."
    return adapter, nothing
end

function _workflow_state(ctx::AgentContext, adapter)
    calibrated = ctx.calibration_available && ctx.calibration_model == adapter.name
    return WorkflowState(
        adapter.name,
        calibrated,
        calibrated ? ctx.last_calibration : nothing,
        ctx.last_spec,
        ctx.result_model == adapter.name ? ctx.last_result : nothing,
    )
end

function _run(req::ActionRequest, kind::Symbol; ctx=nothing)
    ctx isa AgentContext || return response(req.id; ok=false, error="No agent context is available.")
    name = get(req.payload, :name, nothing)
    name isa AbstractString || return response(req.id; ok=false, error="payload[:name] must be a string.")
    parameters = get(req.payload, :parameters, Dict{Symbol,Any}())
    parameters isa AbstractDict || return response(req.id; ok=false, error="payload[:parameters] must be an object.")

    adapter, selection_error = _selected_adapter(req, ctx)
    selection_error === nothing || return response(req.id; ok=false, error=selection_error)
    registry = kind === :scenario ? adapter.scenarios : adapter.experiments
    workflow = get(registry, String(name), nothing)
    workflow === nothing && return response(req.id; ok=false, error="Model $(adapter.name) does not declare $(kind) $(name).")

    parameter_status = workflow_parameter_status(workflow, parameters)
    parameter_status[:valid] || return response(
        req.id;
        ok=false,
        error=_parameter_error(parameter_status),
    )
    raw_result, result = try
        run_workflow(workflow, _workflow_state(ctx, adapter), parameters)
    catch err
        return response(req.id; ok=false, error="Model $(kind) $(workflow.name) failed: $(sprint(showerror, err))")
    end
    ctx.workflow_model = adapter.name
    ctx.workflow_kind = kind
    ctx.workflow_name = workflow.name
    ctx.last_workflow = raw_result
    ctx.report_model = nothing
    ctx.report_name = nothing
    ctx.last_report = nothing
    record_provenance!(ctx;
        event=kind,
        model=adapter.name,
        details=Dict(
            :name => workflow.name,
            :parameters => parameters,
            :parameter_status => parameter_status,
            :packages => package_inventory(),
        ),
    )
    return response(req.id; data=Dict(
        :model => adapter.name,
        :workflow => Dict(
            :kind => String(kind),
            :name => workflow.name,
            :parameter_status => parameter_status,
        ),
        :result => result,
    ))
end

function _parameter_error(status)
    parts = String[]
    isempty(status[:missing]) || push!(parts, "missing required parameters: $(join(status[:missing], ", "))")
    isempty(status[:invalid]) || push!(parts, "invalid parameters: $(join(sort(collect(keys(status[:invalid]))), ", "))")
    return join(parts, "; ")
end

scenario_handler(req::ActionRequest; ctx=nothing) = _run(req, :scenario; ctx=ctx)
experiment_handler(req::ActionRequest; ctx=nothing) = _run(req, :experiment; ctx=ctx)

end # module
