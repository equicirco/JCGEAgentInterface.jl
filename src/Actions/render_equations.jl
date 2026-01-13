"""
Render equations for a model.
"""
module RenderEquations

using ..Schema: ActionRequest, response
using ..Context: AgentContext
using JCGEOutput

export handler

"""
    handler(req; ctx=nothing)

Render equations for the last solved model or a named model.
"""
function handler(req::ActionRequest; ctx=nothing)
    target = nothing
    format = Symbol(get(req.payload, :format, :markdown))
    if ctx isa AgentContext
        target = ctx.last_result !== nothing ? ctx.last_result : ctx.last_spec
    end
    if target === nothing
        return response(req.id; ok=false, error="No model in context. Solve or load a model first.")
    end
    text = JCGEOutput.render_equations(target; format=format)
    return response(req.id; data=Dict(:format => String(format), :text => text))
end

end # module
