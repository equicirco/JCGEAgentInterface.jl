"""
Run a model-owned calibration workflow.
"""
module CalibrateModel

using ..Schema: ActionRequest, response
using ..Context: AgentContext, active_model_adapter, model_adapter, record_provenance!
using ..Adapters: calibration_input_status
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

Run the selected model's declared calibration callback with structured inputs.
The resulting artifact remains in the context for a compatible model builder;
the MCP response contains only completion metadata.
"""
function handler(req::ActionRequest; ctx=nothing)
    ctx isa AgentContext || return response(req.id; ok=false, error="No agent context is available.")
    inputs = get(req.payload, :inputs, nothing)
    inputs isa AbstractDict || return response(req.id; ok=false, error="payload[:inputs] must be an object.")

    adapter, selection_error = _selected_adapter(req, ctx)
    selection_error === nothing || return response(req.id; ok=false, error=selection_error)
    adapter.calibrate === nothing &&
        return response(req.id; ok=false, error="Model $(adapter.name) does not declare a calibration workflow.")

    input_status = calibration_input_status(adapter, inputs)
    input_status[:valid] || return response(
        req.id;
        ok=false,
        error="Missing required calibration inputs: $(join(input_status[:missing], ", ")).",
    )

    artifact = try
        adapter.calibrate(inputs)
    catch err
        return response(req.id; ok=false, error="Model calibration failed: $(sprint(showerror, err))")
    end
    ctx.calibration_model = adapter.name
    ctx.calibration_available = true
    ctx.last_calibration = artifact
    ctx.workflow_model = nothing
    ctx.workflow_kind = nothing
    ctx.workflow_name = nothing
    ctx.last_workflow = nothing
    ctx.result_model = nothing
    ctx.last_spec = nothing
    ctx.last_result = nothing
    ctx.report_model = nothing
    ctx.report_name = nothing
    ctx.last_report = nothing
    record_provenance!(ctx;
        event=:calibrated,
        model=adapter.name,
        details=Dict(
            :inputs => inputs,
            :input_status => input_status,
            :check_available => adapter.check_calibration !== nothing,
            :packages => package_inventory(),
        ),
    )
    return response(req.id; data=Dict(
        :model => adapter.name,
        :calibration => Dict(
            :completed => true,
            :input_status => input_status,
            :check_available => adapter.check_calibration !== nothing,
        ),
    ))
end

end # module
