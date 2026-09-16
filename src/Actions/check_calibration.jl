"""
Run a model-owned calibration check for the latest calibration artifact.
"""
module CheckCalibration

using ..Schema: ActionRequest, response
using ..Context: AgentContext, active_model_adapter, model_adapter, record_provenance!
using ..Adapters: calibration_diagnostics
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

"""
    handler(req; ctx=nothing)

Run the selected model's declared calibration-check callback against the latest
artifact produced for that same model.
"""
function handler(req::ActionRequest; ctx=nothing)
    ctx isa AgentContext || return response(req.id; ok=false, error="No agent context is available.")
    adapter, selection_error = _selected_adapter(req, ctx)
    selection_error === nothing || return response(req.id; ok=false, error=selection_error)
    adapter.check_calibration === nothing &&
        return response(req.id; ok=false, error="Model $(adapter.name) does not declare a calibration check.")
    ctx.calibration_model == adapter.name && ctx.calibration_available ||
        return response(req.id; ok=false, error="No calibration artifact is available for model $(adapter.name).")

    diagnostics = try
        calibration_diagnostics(adapter, ctx.last_calibration)
    catch err
        return response(req.id; ok=false, error="Calibration check failed: $(sprint(showerror, err))")
    end
    record_provenance!(ctx;
        event=:calibration_checked,
        model=adapter.name,
        details=Dict(:diagnostics => diagnostics, :packages => package_inventory()),
    )
    return response(req.id; data=Dict(
        :model => adapter.name,
        :diagnostics => diagnostics,
    ))
end

end # module
