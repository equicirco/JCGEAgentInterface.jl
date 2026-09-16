"""
Solve a RunSpec or model reference.
"""
module Solve

using ..Schema: ActionRequest, response
using ..Context: AgentContext, active_model_adapter, model_adapter
using ..Adapters: build_model
using ..Context: record_provenance!
using ..Catalog: package_inventory
using JCGECore
using JCGERuntime

export handler

"""
    handler(req; ctx=nothing)

Solve a model referenced in the context or payload.
"""
function handler(req::ActionRequest; ctx=nothing)
    spec = nothing
    adapter = nothing
    if ctx isa AgentContext
        adapter = active_model_adapter(ctx)
    end
    if haskey(req.payload, :model) && ctx isa AgentContext
        adapter = model_adapter(ctx, String(req.payload[:model]))
        adapter === nothing && return response(req.id; ok=false, error="Unknown model $(req.payload[:model])")
        ctx.active_model = adapter.name
    end
    if adapter !== nothing
        calibration = ctx isa AgentContext && ctx.calibration_model == adapter.name ? ctx.last_calibration : nothing
        spec = build_model(adapter; calibration=calibration)
    elseif ctx isa AgentContext
        # Retain support for callers that populated last_spec directly before
        # the adapter contract was introduced.
        spec = ctx.last_spec
    end
    if spec === nothing
        return response(req.id; ok=false, error="No model in context. Use load_model first.")
    end
    spec isa JCGECore.RunSpec || return response(req.id; ok=false, error="Model did not resolve to RunSpec.")

    optimizer = get(req.payload, :optimizer, nothing)
    opt = nothing
    if optimizer !== nothing
        opt_sym = Symbol(optimizer)
        if opt_sym == :Ipopt
            try
                @eval import Ipopt
                opt = Ipopt.Optimizer
            catch
                return response(req.id; ok=false, error="Ipopt not available.")
            end
        elseif opt_sym == :PATHSolver
            try
                @eval import PATHSolver
                opt = PATHSolver.Optimizer
            catch
                return response(req.id; ok=false, error="PATHSolver not available.")
            end
        end
    end

    result = JCGERuntime.run!(spec; optimizer=opt)
    if ctx isa AgentContext
        ctx.last_spec = spec
        ctx.last_result = result
        ctx.result_model = adapter === nothing ? nothing : adapter.name
        ctx.report_model = nothing
        ctx.report_name = nothing
        ctx.last_report = nothing
        record_provenance!(ctx;
            event=:solved,
            model=adapter === nothing ? ctx.active_model : adapter.name,
            details=Dict(
                :optimizer => optimizer === nothing ? nothing : String(optimizer),
                :calibration_available => ctx.calibration_available && ctx.calibration_model == ctx.active_model,
                :packages => package_inventory(),
            ),
        )
    end
    return response(req.id; data=Dict(:summary => result.summary))
end

end # module
