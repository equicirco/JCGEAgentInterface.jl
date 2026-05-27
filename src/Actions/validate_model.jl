"""
Validate the last solved JCGE model context.
"""
module ValidateModel

using ..Schema: ActionRequest, response
using ..Context: AgentContext
using JCGERuntime

export handler

function handler(req::ActionRequest; ctx=nothing)
    if !(ctx isa AgentContext) || ctx.last_result === nothing
        return response(req.id; ok=false, error="No solved model context available. Solve a model first.")
    end
    level = Symbol(get(req.payload, :level, :basic))
    tol = Float64(get(req.payload, :tol, 1e-6))
    report = JCGERuntime.validate_model(ctx.last_result.context; level=level, tol=tol)
    return response(req.id; data=Dict(:level => String(level), :tol => tol, :report => report))
end

end # module
