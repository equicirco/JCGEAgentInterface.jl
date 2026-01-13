"""
Load or reference a model by name.
"""
module LoadModel

using ..Schema: ActionRequest, response
using ..Context: AgentContext

export handler

"""
    handler(req; ctx=nothing)

Return a model reference. Expects `payload[:name]`.
"""
function handler(req::ActionRequest; ctx=nothing)
    name = get(req.payload, :name, nothing)
    name === nothing && return response(req.id; ok=false, error="Missing payload[:name]")
    if ctx isa AgentContext
        if haskey(ctx.models, String(name))
            ctx.last_spec = ctx.models[String(name)]
        else
            return response(req.id; ok=false, error="Unknown model $(name)")
        end
    end
    return response(req.id; data=Dict(:model => String(name)))
end

end # module
