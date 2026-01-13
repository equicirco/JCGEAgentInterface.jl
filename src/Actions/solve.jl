"""
Solve a RunSpec or model reference.
"""
module Solve

using ..Schema: ActionRequest, response
using ..Context: AgentContext
using JCGECore
using JCGERuntime

export handler

"""
    handler(req; ctx=nothing)

Solve a model referenced in the context or payload.
"""
function handler(req::ActionRequest; ctx=nothing)
    spec = nothing
    if ctx isa AgentContext
        spec = ctx.last_spec
    end
    if haskey(req.payload, :model) && ctx isa AgentContext
        model_ref = ctx.models[String(req.payload[:model])]  # may throw
        spec = model_ref
    end
    if spec === nothing
        return response(req.id; ok=false, error="No model in context. Use load_model first.")
    end
    if spec isa Function
        spec = spec()
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
    end
    return response(req.id; data=Dict(:summary => result.summary))
end

end # module
