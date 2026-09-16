"""
Load or reference a model by name.
"""
module LoadModel

using ..Schema: ActionRequest, response
using ..Context: AgentContext, model_adapter, record_provenance!
using ..Adapters: adapter_summary
using ..Catalog: package_inventory

export handler

"""
    handler(req; ctx=nothing)

Return a model reference. Expects `payload[:name]`.
"""
function handler(req::ActionRequest; ctx=nothing)
    name = get(req.payload, :name, nothing)
    name === nothing && return response(req.id; ok=false, error="Missing payload[:name]")
    if ctx isa AgentContext
        adapter = model_adapter(ctx, String(name))
        if adapter === nothing
            return response(req.id; ok=false, error="Unknown model $(name)")
        end
        ctx.active_model = adapter.name
        ctx.calibration_model = nothing
        ctx.calibration_available = false
        ctx.last_calibration = nothing
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
            event=:model_loaded,
            model=adapter.name,
            details=Dict(
                :adapter => adapter_summary(adapter),
                :packages => package_inventory(),
            ),
        )
        return response(req.id; data=Dict(:model => adapter_summary(adapter)))
    end
    return response(req.id; data=Dict(:model => String(name)))
end

end # module
