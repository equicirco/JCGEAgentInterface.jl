"""
Run a named model-owned reporter.
"""
module RunReporter

using ..Schema: ActionRequest, response
using ..Context: AgentContext, active_model_adapter, model_adapter, record_provenance!
using ..Adapters: adapter_summary, run_reporter
using ..Catalog: package_inventory

export handler

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

function _report_source(req::ActionRequest, ctx::AgentContext, adapter)
    requested = get(req.payload, :source, nothing)
    source_name = requested === nothing ?
        (ctx.workflow_model == adapter.name ? "workflow" : "solve") : String(requested)
    if source_name == "workflow"
        ctx.workflow_model == adapter.name && ctx.last_workflow !== nothing ||
            return nothing, nothing, "No workflow result is available for model $(adapter.name)."
        return ctx.last_workflow, source_name, nothing
    elseif source_name == "solve"
        ctx.result_model == adapter.name && ctx.last_result !== nothing ||
            return nothing, nothing, "No solved result is available for model $(adapter.name)."
        return ctx.last_result, source_name, nothing
    end
    return nothing, nothing, "payload[:source] must be workflow or solve."
end

"""
    handler(req; ctx=nothing)

Run one explicitly declared reporter against a result from the same model.
"""
function handler(req::ActionRequest; ctx=nothing)
    ctx isa AgentContext || return response(req.id; ok=false, error="No agent context is available.")
    name = get(req.payload, :name, nothing)
    name isa AbstractString || return response(req.id; ok=false, error="payload[:name] must be a string.")
    adapter, selection_error = _selected_adapter(req, ctx)
    selection_error === nothing || return response(req.id; ok=false, error=selection_error)
    haskey(adapter.reporters, String(name)) ||
        return response(req.id; ok=false, error="Model $(adapter.name) does not declare reporter $(name).")
    source, source_name, source_error = _report_source(req, ctx, adapter)
    source_error === nothing || return response(req.id; ok=false, error=source_error)

    raw_report, report = try
        run_reporter(adapter, String(name), source)
    catch err
        return response(req.id; ok=false, error="Reporter $(name) failed: $(sprint(showerror, err))")
    end
    ctx.report_model = adapter.name
    ctx.report_name = String(name)
    ctx.last_report = raw_report
    indicators = adapter_summary(adapter)[:indicators]
    record_provenance!(ctx;
        event=:reported,
        model=adapter.name,
        details=Dict(
            :reporter => String(name),
            :source => source_name,
            :indicators => indicators,
            :report => report,
            :packages => package_inventory(),
        ),
    )
    return response(req.id; data=Dict(
        :model => adapter.name,
        :reporter => String(name),
        :source => source_name,
        :indicators => indicators,
        :report => report,
    ))
end

end # module
